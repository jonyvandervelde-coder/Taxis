//
//  ReceiptExtractionService.swift
//  TaxÍs
//
//  Sends OCR'd Icelandic receipt/invoice text to Claude (Anthropic Messages
//  API) using forced tool-use, so the model can only respond in the exact
//  JSON shape ExtractedTransaction expects — vendor, ISK totals, and the
//  correct VSK (VAT) category (24% standard / 11% reduced / 0% exempt).
//
//  ── SECURITY NOTE ──────────────────────────────────────────────────────
//  This class no longer calls api.anthropic.com directly. It calls the
//  `receipt-extraction` Supabase Edge Function (see
//  supabase/functions/receipt-extraction/index.ts), which holds the real
//  Anthropic key server-side. The only credential this class stores or
//  sends is the signed-in user's short-lived, revocable Supabase session
//  access token (see SupabaseSession.swift) — never the provider key. The
//  request/response contract with the Edge Function matches the Anthropic
//  Messages API exactly, so buildRequestBody/parseExtractedTransaction
//  below didn't need to change, only buildURLRequest and where the
//  credential comes from.
//

import Foundation

// MARK: - Errors

enum ReceiptExtractionError: LocalizedError {
    case emptyInputText
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String)
    case rateLimited(retryAfterSeconds: Double?)
    case noToolUseBlockInResponse
    case decodingFailed(underlying: Error)
    case arithmeticInconsistency(ExtractedTransaction)
    case categoryRateMismatch(ExtractedTransaction)

    var errorDescription: String? {
        switch self {
        case .emptyInputText:
            return "The receipt/invoice text was empty — nothing to extract."
        case .invalidHTTPResponse:
            return "The server returned a non-HTTP response."
        case .httpError(let statusCode, let body):
            return "AI provider returned HTTP \(statusCode): \(body)"
        case .rateLimited(let retryAfterSeconds):
            if let retryAfterSeconds {
                return "Rate limited by the AI provider. Retry after \(retryAfterSeconds)s."
            }
            return "Rate limited by the AI provider."
        case .noToolUseBlockInResponse:
            return "The model responded without using the required extraction tool."
        case .decodingFailed(let underlying):
            return "Failed to decode the extracted transaction: \(underlying.localizedDescription)"
        case .arithmeticInconsistency(let transaction):
            return "Extracted amounts don't add up: \(transaction.netAmountISK) + \(transaction.vskAmountISK) ≠ \(transaction.totalAmountISK)."
        case .categoryRateMismatch(let transaction):
            return "vsk_rate (\(transaction.vskRate)) doesn't match the canonical rate for \(transaction.vskCategory.rawValue)."
        }
    }
}

// MARK: - Service

final class ReceiptExtractionService {

    static let shared = ReceiptExtractionService()

    /// Model used for extraction. claude-sonnet-5 is the default for
    /// accuracy on messy OCR text; swap to claude-haiku-4-5-20251001 if
    /// you want a cheaper/faster model for high receipt volume and are
    /// comfortable with the manual-review threshold catching more cases.
    private let model = "claude-sonnet-5"

    /// Name of the Edge Function this service calls — see
    /// supabase/functions/receipt-extraction/index.ts.
    private let edgeFunctionName = "receipt-extraction"

    private let session: URLSession
    private let decoder: JSONDecoder
    private let maxRetries = 3

    /// The full Anthropic response JSON from the most recent successful
    /// extraction — callers persist this into `transactions.ai_raw_response`
    /// (see taxis_schema.sql) as the audit trail. `nil` until the first
    /// extraction completes.
    private(set) var lastRawResponseJSON: [String: Any]?

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    // MARK: Public API

    /// Sends raw OCR'd text from a receipt or invoice to the AI model and
    /// returns a validated, structured transaction.
    ///
    /// - Parameters:
    ///   - rawText: Text extracted from the receipt/invoice image (e.g. via
    ///     VisionKit/VNRecognizeTextRequest upstream of this call).
    ///   - sourceDocumentType: Whether this came from a receipt, invoice, or payslip.
    /// - Returns: A structured, arithmetic-validated `ExtractedTransaction`.
    /// - Throws: `ReceiptExtractionError` on any failure — network, HTTP,
    ///   decoding, or validation.
    func extractTransaction(
        fromRawText rawText: String,
        sourceDocumentType: SourceDocumentType = .receipt
    ) async throws -> ExtractedTransaction {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReceiptExtractionError.emptyInputText
        }

        let accessToken = try SupabaseSession.currentAccessToken()

        let requestBody = try buildRequestBody(rawText: trimmed, sourceDocumentType: sourceDocumentType)
        let urlRequest = try buildURLRequest(accessToken: accessToken, body: requestBody)

        let responseData = try await sendWithRetry(urlRequest)
        let transaction = try parseExtractedTransaction(from: responseData)

        guard transaction.isArithmeticallyConsistent else {
            throw ReceiptExtractionError.arithmeticInconsistency(transaction)
        }
        guard transaction.isCategoryRateConsistent else {
            throw ReceiptExtractionError.categoryRateMismatch(transaction)
        }

        return transaction
    }

    /// Policy helper: whether this transaction should be routed to the
    /// user for manual confirmation before being written as `confirmed`
    /// (vs. `pending_review`) in the transactions table. Mirrors the
    /// "OCR confidence-handling protocol" flagged as a required
    /// architectural concern in the TaxÍs spec.
    func requiresManualReview(_ transaction: ExtractedTransaction) -> Bool {
        let confidenceThreshold = 0.75
        // vendor_kennitala is always omitted for payslips by design (see the
        // privacy rule in systemPrompt) — its absence there isn't a signal
        // of a bad extraction the way it is for receipts/invoices.
        let missingKennitalaIsConcerning = transaction.sourceDocumentType != .payslip
        return transaction.aiConfidence < confidenceThreshold
            || (missingKennitalaIsConcerning && transaction.vendorKennitala == nil)
    }

    // MARK: - Request construction

    private func buildURLRequest(accessToken: String, body: Data) throws -> URLRequest {
        let url = try SupabaseConfig.functionsURL.appendingPathComponent(edgeFunctionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func buildRequestBody(rawText: String, sourceDocumentType: SourceDocumentType) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0,
            "system": systemPrompt,
            "tools": [toolSchema],
            "tool_choice": ["type": "tool", "name": toolName],
            "messages": [
                [
                    "role": "user",
                    "content": "Source document type: \(sourceDocumentType.rawValue)\n\nRaw OCR text:\n\(rawText)"
                ]
            ]
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private var systemPrompt: String {
        """
        You are an accounting extraction engine for TaxÍs, an Icelandic tax \
        app. You are given raw OCR text from an Icelandic receipt or \
        invoice and must extract structured transaction data by calling \
        the \(toolName) tool. Never respond in plain text.

        Rules:
        1. Amounts are in Icelandic króna (ISK). Icelandic number formatting \
           uses "." as the thousands separator and "," as the decimal \
           separator (e.g. "1.234,56" kr means 1234.56 ISK). Convert to \
           plain decimal numbers with "." as the decimal separator in your \
           output.
        2. total_amount_isk is the final amount paid, including VSK. \
           net_amount_isk is the amount before VSK. vsk_amount_isk is the \
           VSK charged. These three must satisfy: \
           net_amount_isk + vsk_amount_isk = total_amount_isk.
        3. Classify vsk_category using current Icelandic VSK rules:
           - "standard_24" (24%): most goods and services — electronics, \
             clothing, fuel, alcohol, most retail.
           - "reduced_11" (11%): food and groceries, restaurant/dining \
             service, hotel/accommodation, books, newspapers, and \
             household heating/electricity.
           - "exempt_0" (0%): healthcare, insurance, financial services, \
             residential rent.
           If a receipt clearly mixes rates across line items (e.g. a \
           supermarket receipt with groceries and household goods), \
           populate line_items with each item's own vsk_category and set \
           the top-level vsk_category to whichever rate the majority of \
           the total falls under.
        4. vsk_rate must be the exact decimal rate for the chosen \
           vsk_category: 0.24, 0.11, or 0.
        5. vendor_kennitala is the vendor's 10-digit Icelandic ID number \
           (kennitala), if printed on the receipt. If not present or not \
           legible, omit the field — do not guess.
        5a. PRIVACY — if source_document_type is "payslip": this document is \
           full of personal data (the employee's name, home address, \
           personal kennitala, bank account number) that TaxÍs has no need \
           to store. Extract ONLY the financial figures required by this \
           tool: \
           • total_amount_isk = net pay (what lands in the employee's bank, \
             labelled "Samtals útborgað" or "Útborgun"). \
           • gross_pay_isk = gross salary before all deductions (labelled \
             "Laun alls" or "Bruttólaun"). \
           • tax_withheld_isk = income tax withheld at source (labelled \
             "Staðgreiðsla" or "Staðgreiðsla nú" — use the current-period \
             net figure after persónuafsláttur, not the gross tax line). \
           • net_amount_isk = same as total_amount_isk (wages have no VSK). \
           • vsk_amount_isk = 0, vsk_category = "exempt_0", vsk_rate = 0. \
           • transaction_date = payment date (Útb.dags or Útborgunardagur). \
           Set vendor_name to the EMPLOYER's (company's) name only, never \
           the employee's personal name. ALWAYS omit vendor_kennitala for \
           payslips — never return a personal kennitala, and never return \
           the employer's kennitala either. If the employer's name isn't \
           clearly distinguishable from the employee's on the payslip, omit \
           vendor_name rather than guess which one it is. Do not put any \
           person's name, kennitala, address, or bank account number in the \
           notes field.
        6. transaction_date must be in YYYY-MM-DD format. Icelandic \
           receipts commonly print dates as DD.MM.YYYY — convert \
           accordingly.
        7. ai_confidence is your own confidence in this extraction overall, \
           from 0.0 (largely guessed) to 1.0 (every field clearly legible \
           and unambiguous). Be conservative — this value gates whether a \
           human reviews the result before it's treated as confirmed.
        8. If the OCR text is too garbled to extract a field with any \
           confidence, still return your best estimate but reflect that in \
           a low ai_confidence and a note in the notes field explaining \
           what was unclear. Never fabricate a kennitala or an amount \
           that isn't supported by the text.
        """
    }

    private let toolName = "record_extracted_transaction"

    private var toolSchema: [String: Any] {
        [
            "name": toolName,
            "description": "Records one structured transaction extracted from Icelandic receipt/invoice OCR text.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "vendor_name": ["type": "string", "description": "Business/vendor name as printed on the receipt. For payslips: the employer's company name only — never the employee's personal name."],
                    "vendor_kennitala": ["type": "string", "description": "Vendor's 10-digit Icelandic kennitala, if present. Always omit this for payslips — never a personal kennitala."],
                    "currency": ["type": "string", "description": "Always 'ISK' for now.", "enum": ["ISK"]],
                    "total_amount_isk": ["type": "number", "description": "Gross total paid, including VSK."],
                    "net_amount_isk": ["type": "number", "description": "Net amount before VSK."],
                    "vsk_amount_isk": ["type": "number", "description": "VSK amount charged."],
                    "vsk_category": [
                        "type": "string",
                        "enum": ["standard_24", "reduced_11", "exempt_0"],
                        "description": "The dominant VSK category for this transaction."
                    ],
                    "vsk_rate": ["type": "number", "description": "Decimal VSK rate matching vsk_category: 0.24, 0.11, or 0."],
                    "line_items": [
                        "type": "array",
                        "description": "Optional per-item breakdown when the receipt mixes VSK rates.",
                        "items": [
                            "type": "object",
                            "properties": [
                                "description": ["type": "string"],
                                "amount_isk": ["type": "number"],
                                "vsk_category": ["type": "string", "enum": ["standard_24", "reduced_11", "exempt_0"]]
                            ],
                            "required": ["description", "amount_isk", "vsk_category"]
                        ]
                    ],
                    "transaction_date": ["type": "string", "description": "YYYY-MM-DD"],
                    "ai_confidence": ["type": "number", "description": "0.0–1.0 self-reported extraction confidence."],
                    "source_document_type": ["type": "string", "enum": ["receipt", "invoice", "payslip"]],
                    "notes": ["type": "string", "description": "Anything unclear about the extraction, or omitted."],
                    "gross_pay_isk": ["type": "number", "description": "Payslip only: gross salary before all deductions (Laun alls / bruttólaun). Omit for receipts and invoices."],
                    "tax_withheld_isk": ["type": "number", "description": "Payslip only: income tax withheld at source (Staðgreiðsla nú — net of persónuafsláttur). Omit for receipts and invoices."]
                ],
                "required": [
                    "vendor_name", "currency", "total_amount_isk", "net_amount_isk",
                    "vsk_amount_isk", "vsk_category", "vsk_rate", "transaction_date",
                    "ai_confidence", "source_document_type"
                ]
            ]
        ]
    }

    // MARK: - Networking with retry

    private func sendWithRetry(_ request: URLRequest, attempt: Int = 1) async throws -> Data {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptExtractionError.invalidHTTPResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return data

        case 429, 500, 502, 503, 529:
            // Retryable: rate limit or transient server error.
            guard attempt < maxRetries else {
                if httpResponse.statusCode == 429 {
                    let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after").flatMap(Double.init)
                    throw ReceiptExtractionError.rateLimited(retryAfterSeconds: retryAfter)
                }
                let body = String(data: data, encoding: .utf8) ?? "<no body>"
                throw ReceiptExtractionError.httpError(statusCode: httpResponse.statusCode, body: body)
            }
            let backoffSeconds = pow(2.0, Double(attempt)) // 2s, 4s, 8s...
            try await Task.sleep(nanoseconds: UInt64(backoffSeconds * 1_000_000_000))
            return try await sendWithRetry(request, attempt: attempt + 1)

        default:
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ReceiptExtractionError.httpError(statusCode: httpResponse.statusCode, body: body)
        }
    }

    // MARK: - Response parsing

    /// Anthropic Messages API responses look like:
    /// {
    ///   "content": [
    ///     { "type": "tool_use", "name": "record_extracted_transaction", "input": { ... } }
    ///   ],
    ///   ...
    /// }
    private func parseExtractedTransaction(from data: Data) throws -> ExtractedTransaction {
        let topLevel: [String: Any]
        do {
            guard let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ReceiptExtractionError.noToolUseBlockInResponse
            }
            topLevel = parsed
        } catch {
            throw ReceiptExtractionError.decodingFailed(underlying: error)
        }
        lastRawResponseJSON = topLevel

        guard
            let content = topLevel["content"] as? [[String: Any]],
            let toolUseBlock = content.first(where: { ($0["type"] as? String) == "tool_use" && ($0["name"] as? String) == toolName }),
            let toolInput = toolUseBlock["input"] as? [String: Any]
        else {
            throw ReceiptExtractionError.noToolUseBlockInResponse
        }

        do {
            let inputData = try JSONSerialization.data(withJSONObject: toolInput, options: [])
            return try decoder.decode(ExtractedTransaction.self, from: inputData)
        } catch {
            throw ReceiptExtractionError.decodingFailed(underlying: error)
        }
    }
}
