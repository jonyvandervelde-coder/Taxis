//
//  ReceiptExtractionService.swift
//  TaxÍs
//
//  Sends Vision-extracted raw text (or PDF text layer) to the
//  receipt-extraction Supabase Edge Function, which adds the server-side
//  Anthropic key and forwards to Claude. Claude performs structured
//  extraction via forced tool-use and returns the result.
//
//  ── SECURITY NOTE ──────────────────────────────────────────────────────
//  The system prompt instructs Claude to NEVER extract the employee's
//  personal name, personal kennitala, home address, or bank account
//  number from payslips. vendor_kennitala is always omitted for payslips.
//  ────────────────────────────────────────────────────────────────────────

import Foundation

// MARK: - Errors

enum ReceiptExtractionError: LocalizedError {
    case emptyInputText
    case unparseableDocument
    // Legacy cases kept so any existing catch-sites still compile.
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
            return "Ekki tókst að lesa skjalið sjálfvirkt. Þú getur slegið inn tölurnar handvirkt."
        case .unparseableDocument:
            return "Ekki tókst að greina skjalið. Vinsamlegast sláðu inn handvirkt."
        case .invalidHTTPResponse:
            return "Þjónninn skilaði óvæntri svörun."
        case .httpError(let code, _):
            return "Þjónnvilla \(code). Reyndu aftur."
        case .rateLimited:
            return "Of margar beiðnir. Reyndu eftir smá stund."
        case .noToolUseBlockInResponse:
            return "Greining mistókst — engin gögn fundust."
        case .decodingFailed(let underlying):
            return underlying.localizedDescription
        case .arithmeticInconsistency:
            return "Upphæðir stemma ekki — vinsamlegast yfirfarðu."
        case .categoryRateMismatch:
            return "VSK-flokkur og hlutfall eru ekki í samræmi."
        }
    }
}

// MARK: - Service

final class ReceiptExtractionService {

    static let shared = ReceiptExtractionService()

    private let model = "claude-haiku-4-5-20251001"
    private let edgeFunctionName = "receipt-extraction"
    private let toolName = "extract_transaction"

    private let urlSession: URLSession
    /// Set to the raw Claude response after each successful call — used by
    /// TransactionConfirmationView and the repository's audit log.
    private(set) var lastRawResponseJSON: [String: Any]? = nil

    init(session: URLSession = .shared) {
        self.urlSession = session
    }

    // MARK: - Public API

    func extractTransaction(
        fromRawText rawText: String,
        sourceDocumentType: SourceDocumentType = .payslip
    ) async throws -> ExtractedTransaction {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReceiptExtractionError.emptyInputText }

        let accessToken = try SupabaseSession.currentAccessToken()
        let body = try buildRequestBody(rawText: trimmed, docType: sourceDocumentType)
        let request = try buildURLRequest(accessToken: accessToken, body: body)

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ReceiptExtractionError.invalidHTTPResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "<no body>"
            if http.statusCode == 429 {
                throw ReceiptExtractionError.rateLimited(retryAfterSeconds: nil)
            }
            throw ReceiptExtractionError.httpError(statusCode: http.statusCode, body: bodyText)
        }

        return try parseResult(from: data, docType: sourceDocumentType)
    }

    func requiresManualReview(_ transaction: ExtractedTransaction) -> Bool {
        let threshold = 0.60
        let missingKennitalaIsConcerning = transaction.sourceDocumentType != .payslip
        return transaction.aiConfidence < threshold
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

    private func buildRequestBody(rawText: String, docType: SourceDocumentType) throws -> Data {
        let userMessage = """
        Document type: \(docType.rawValue)

        Raw text extracted from the document:
        ---
        \(rawText)
        ---

        Call extract_transaction with the financial data you find.
        """

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 1024,
            "temperature": 0,
            "system": systemPrompt(for: docType),
            "tools": [toolSchema(for: docType)],
            "tool_choice": ["type": "tool", "name": toolName],
            "messages": [
                ["role": "user", "content": userMessage],
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    private func systemPrompt(for docType: SourceDocumentType) -> String {
        let base = """
        You are a financial data extraction assistant for TaxÍs, an Icelandic personal \
        tax management app. Extract structured financial data from the provided document \
        text and call the extract_transaction tool exactly once.

        Icelandic number format: "." is the thousands separator, "," is the decimal \
        point. Examples: "1.234,56" = 1234.56; "245.680" = 245680; "680" = 680. \
        Always return amounts as plain decimal numbers (no dots, no commas, no "kr." suffix).

        Date format: return dates as YYYY-MM-DD. Icelandic dates are commonly DD.MM.YYYY.

        If a field cannot be reliably determined, omit it or return null rather than guessing.
        """

        switch docType {
        case .payslip:
            return base + """


        ⚠️ MANDATORY SECURITY RULES FOR PAYSLIPS — do not deviate:
        • vendor_name: Return ONLY the employer's company name if it clearly contains a \
          legal-entity suffix such as ehf., hf., sf., ohf., ses., slhf., ráðgjöf, \
          þjónusta, stofnun, sveit, ríkis, ltd., corp., inc. — if no clear company \
          name is found, return "Launagreiðandi". NEVER return an employee's personal \
          name, regardless of how prominently it appears.
        • vendor_kennitala: ALWAYS null. Never extract any kennitala for payslips.
        • NEVER extract: home address, bank account number, national ID (kennitala).

        Fields to look for:
        • net_amount_isk  — net pay / take-home (útborgun, útborgað, samtals útborgað, \
          til útgreiðslu)
        • gross_pay_isk   — gross salary (laun alls, bruttólaun, heildarlaun)
        • tax_withheld_isk — income tax withheld (staðgreiðsla, staðgr., skattur)
        • transaction_date — payment date (útb.dags., greiðsludagur, dags.)
        • confidence      — 0.90 if net pay clearly identified, 0.55 if ambiguous
        """

        case .receipt, .invoice:
            return base + """


        Fields to look for:
        • total_amount_isk — total charged (samtals, heildarupphæð, til greiðslu)
        • vsk_amount_isk   — VAT amount (VSK, virðisaukaskattur, mva.)
        • vsk_rate         — VAT percentage as a plain number: 24, 11, or 0. \
          Standard is 24 %; reduced 11 % applies to food, hotels, books, heating.
        • vendor_name      — business name (first prominent non-numeric line)
        • vendor_kennitala — business registration number from footer (format \
          XXXXXX-XXXX or 10 digits, NOT a personal ID)
        • transaction_date — purchase date
        • confidence       — 0.85 if total clearly labeled, 0.55 if inferred
        """
        }
    }

    private func toolSchema(for docType: SourceDocumentType) -> [String: Any] {
        var properties: [String: Any] = [
            "vendor_name": [
                "type": "string",
                "description": "Business or employer name",
            ],
            "transaction_date": [
                "type": "string",
                "description": "Date as YYYY-MM-DD",
            ],
            "total_amount_isk": [
                "type": "number",
                "description": "Total amount or net pay in ISK",
            ],
            "net_amount_isk": [
                "type": "number",
                "description": "Pre-VAT amount (for payslips: same as total)",
            ],
            "vsk_amount_isk": [
                "type": "number",
                "description": "VAT amount in ISK (0 for payslips)",
            ],
            "vsk_rate": [
                "type": "number",
                "description": "VAT rate: 24, 11, or 0",
            ],
            "confidence": [
                "type": "number",
                "description": "Extraction confidence from 0 to 1",
            ],
        ]

        if docType == .payslip {
            properties["gross_pay_isk"] = [
                "type": "number",
                "description": "Gross salary before deductions",
            ]
            properties["tax_withheld_isk"] = [
                "type": "number",
                "description": "Income tax (staðgreiðsla) withheld",
            ]
            properties["notes"] = [
                "type": "string",
                "description": "Any important caveats about the extraction",
            ]
        } else {
            properties["vendor_kennitala"] = [
                "type": "string",
                "description": "Business registration number (omit if not found)",
            ]
        }

        return [
            "name": toolName,
            "description": "Records extracted financial data from an Icelandic payslip, receipt, or invoice.",
            "input_schema": [
                "type": "object",
                "properties": properties,
                "required": ["vendor_name", "total_amount_isk", "confidence"],
            ],
        ]
    }

    // MARK: - Response parsing

    private func parseResult(from data: Data, docType: SourceDocumentType) throws -> ExtractedTransaction {
        guard
            let topLevel = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = topLevel["content"] as? [[String: Any]],
            let toolBlock = content.first(where: {
                ($0["type"] as? String) == "tool_use" && ($0["name"] as? String) == toolName
            }),
            let input = toolBlock["input"] as? [String: Any]
        else {
            throw ReceiptExtractionError.noToolUseBlockInResponse
        }

        lastRawResponseJSON = input

        let vendorName = (input["vendor_name"] as? String) ?? "Launagreiðandi"
        let confidence = (input["confidence"] as? Double) ?? 0.5
        let dateString = input["transaction_date"] as? String
        let transactionDate = parseISO(dateString) ?? Date()

        let totalISK  = decimal(from: input["total_amount_isk"]) ?? Decimal(0)
        let netISK    = decimal(from: input["net_amount_isk"]) ?? totalISK
        let vskISK    = decimal(from: input["vsk_amount_isk"]) ?? Decimal(0)
        let vskRateN  = (input["vsk_rate"] as? Double) ?? (docType == .payslip ? 0 : 24)

        let (vskCategory, vskRate): (VSKCategory, Decimal)
        switch vskRateN {
        case 11:  (vskCategory, vskRate) = (.reduced11, Decimal(string: "0.11")!)
        case 0:   (vskCategory, vskRate) = (.exempt0,   Decimal(0))
        default:  (vskCategory, vskRate) = (.standard24, Decimal(string: "0.24")!)
        }

        let grossPayISK     = docType == .payslip ? decimal(from: input["gross_pay_isk"])     : nil
        let taxWithheldISK  = docType == .payslip ? decimal(from: input["tax_withheld_isk"])  : nil
        let notes           = input["notes"] as? String
        let kennitala       = docType != .payslip ? input["vendor_kennitala"] as? String       : nil

        return ExtractedTransaction(
            vendorName: vendorName,
            vendorKennitala: kennitala,
            currency: "ISK",
            totalAmountISK: totalISK,
            netAmountISK: netISK,
            vskAmountISK: vskISK,
            vskCategory: vskCategory,
            vskRate: vskRate,
            lineItems: nil,
            transactionDate: transactionDate,
            aiConfidence: min(max(confidence, 0), 1),
            sourceDocumentType: docType,
            notes: notes,
            grossPayISK: grossPayISK,
            taxWithheldISK: taxWithheldISK
        )
    }

    // MARK: - Helpers

    private func decimal(from value: Any?) -> Decimal? {
        if let n = value as? NSNumber { return Decimal(n.doubleValue) }
        if let s = value as? String   { return Decimal(string: s) }
        return nil
    }

    private func parseISO(_ s: String?) -> Date? {
        guard let s else { return nil }
        return ExtractedTransaction.dateOnlyFormatter.date(from: s)
    }
}
