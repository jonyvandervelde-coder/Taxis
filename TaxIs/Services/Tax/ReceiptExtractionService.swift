//
//  ReceiptExtractionService.swift
//  TaxÍs
//
//  On-device structured extraction from Icelandic receipts, invoices, and
//  payslips using regex pattern matching on Vision-framework OCR text.
//  No external API calls — works fully offline and for free.
//
//  ── SECURITY NOTE ──────────────────────────────────────────────────────
//  Payslip extraction is restricted to financial figures only.
//  This parser NEVER stores or surfaces: the employee's personal name,
//  personal kennitala, home address, or bank account number.
//  vendor_kennitala is always omitted for payslips by design.
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
            return "Tómur texti — ekkert að vinna með."
        case .unparseableDocument:
            return "Ekki tókst að lesa skjalið. Reyndu með skýrari mynd."
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

    /// Kept for source compatibility — always nil in the on-device path.
    private(set) var lastRawResponseJSON: [String: Any]? = nil

    init() {}

    // MARK: - Public API

    /// Parses raw OCR text from a receipt, invoice, or payslip and returns a
    /// validated `ExtractedTransaction`. Runs entirely on-device — no network.
    func extractTransaction(
        fromRawText rawText: String,
        sourceDocumentType: SourceDocumentType = .receipt
    ) async throws -> ExtractedTransaction {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ReceiptExtractionError.emptyInputText }

        let lines = trimmed
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        switch sourceDocumentType {
        case .payslip:
            return try parsePayslip(lines: lines, raw: trimmed)
        case .receipt, .invoice:
            return try parseReceiptOrInvoice(lines: lines, raw: trimmed, docType: sourceDocumentType)
        }
    }

    /// Returns true when the transaction should be flagged for human review
    /// before being written as `confirmed`.
    func requiresManualReview(_ transaction: ExtractedTransaction) -> Bool {
        let threshold = 0.60
        let missingKennitalaIsConcerning = transaction.sourceDocumentType != .payslip
        return transaction.aiConfidence < threshold
            || (missingKennitalaIsConcerning && transaction.vendorKennitala == nil)
    }

    // MARK: - Payslip parsing
    //
    // SECURITY: Only financial figures are extracted.
    // Personal name, personal kennitala, home address, and bank account
    // numbers are NEVER stored or returned, even if present in the text.

    private func parsePayslip(lines: [String], raw: String) throws -> ExtractedTransaction {
        var confidence = 0.40
        var notes: [String] = []

        // ── Net pay (what lands in the employee's bank) ────────────────────
        // Labels: Samtals útborgað, Útborgun, Útborgað, Greiðsla
        let netPatterns: [String] = [
            #"(?:samtals\s+)?útborg(?:að|un)\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"greiðsla\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"net\s*(?:pay|laun)\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"til\s+útgreiðslu\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
        ]
        let netPay = firstDecimal(patterns: netPatterns, in: raw)
        if netPay != nil { confidence += 0.25 }

        // ── Gross pay (before deductions) ─────────────────────────────────
        // Labels: Laun alls, Bruttólaun, Heildarlaun
        let grossPatterns: [String] = [
            #"laun\s+alls?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"bruttólaun\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"heildarlaun\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"gross\s*(?:pay|salary)\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
        ]
        let grossPay = firstDecimal(patterns: grossPatterns, in: raw)
        if grossPay != nil { confidence += 0.10 }

        // ── Income tax withheld ────────────────────────────────────────────
        // Labels: Staðgreiðsla, Staðgreiðsla nú, Skattur
        let taxPatterns: [String] = [
            #"staðgreiðsla\s*(?:nú)?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"staðgr\.?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"skattur\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"income\s+tax\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
        ]
        let taxWithheld = firstDecimal(patterns: taxPatterns, in: raw)
        if taxWithheld != nil { confidence += 0.10 }

        // ── Payment date ──────────────────────────────────────────────────
        let datePatterns: [String] = [
            #"útb\.?\s*dags\.?\s*[:\-–]?\s*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
            #"útborgunardagur\s*[:\-–]?\s*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
            #"greiðsludagur\s*[:\-–]?\s*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
            #"dags(?:etning)?\s*[:\-–]?\s*(\d{1,2}[.\-/]\d{1,2}[.\-/]\d{2,4})"#,
            #"(\d{4}-\d{2}-\d{2})"#,
            #"(\d{1,2}\.\d{1,2}\.\d{4})"#,
        ]
        let dateRaw = firstString(patterns: datePatterns, in: raw)
        let transactionDate = parseDate(dateRaw) ?? Date()
        if dateRaw != nil { confidence += 0.10 }

        // ── Employer name ─────────────────────────────────────────────────
        // SECURITY: Only return when the line is clearly a company name
        // (contains a legal-form suffix). Never return a person's name.
        let employerName = extractEmployerName(lines: lines, raw: raw)

        // ── Best-effort fallback if net pay not found ─────────────────────
        let finalNetPay: Decimal
        if let netPay {
            finalNetPay = netPay
        } else {
            // Use the largest number on the page as a low-confidence guess
            let allAmounts = allDecimalAmounts(in: raw)
            finalNetPay = allAmounts.max() ?? Decimal(0)
            confidence = 0.20
            notes.append("Nettólaun fundust ekki — vinsamlegast staðfestu upphæð.")
        }

        return ExtractedTransaction(
            vendorName: employerName ?? "Launagreiðandi",
            vendorKennitala: nil,         // SECURITY: Always nil for payslips
            currency: "ISK",
            totalAmountISK: finalNetPay,
            netAmountISK: finalNetPay,    // wages have no VSK
            vskAmountISK: Decimal(0),
            vskCategory: .exempt0,
            vskRate: Decimal(0),
            lineItems: nil,
            transactionDate: transactionDate,
            aiConfidence: min(confidence, 0.90),
            sourceDocumentType: .payslip,
            notes: notes.isEmpty ? nil : notes.joined(separator: "; "),
            grossPayISK: grossPay,
            taxWithheldISK: taxWithheld
        )
    }

    // MARK: - Receipt / invoice parsing

    private func parseReceiptOrInvoice(
        lines: [String],
        raw: String,
        docType: SourceDocumentType
    ) throws -> ExtractedTransaction {
        var confidence = 0.35
        var notes: [String] = []

        // ── Total amount ─────────────────────────────────────────────────
        let totalPatterns: [String] = [
            #"samtals?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)\s*(?:kr\.?|isk)?"#,
            #"heildarupphæð\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"til\s+greiðslu\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"(?:^|\b)total\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"(?:^|\b)grand\s*total\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
        ]
        let total: Decimal
        if let found = firstDecimal(patterns: totalPatterns, in: raw) {
            total = found
            confidence += 0.25
        } else {
            // Fallback: take the largest number on the receipt
            let amounts = allDecimalAmounts(in: raw)
            total = amounts.max() ?? Decimal(0)
            confidence -= 0.10
            notes.append("Heildarupphæð giskaður — vinsamlegast staðfestu.")
        }

        // ── Explicit VSK line ─────────────────────────────────────────────
        let vskPatterns: [String] = [
            #"vsk\s*\(?\s*24\s*%\s*\)?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"vsk\s*\(?\s*11\s*%\s*\)?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"(?:^|\b)vsk\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"virðisaukaskattur\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
            #"mva\.?\s*[:\-–]?\s*([0-9][0-9.]*(?:,[0-9]+)?)"#,
        ]
        let explicitVSK = firstDecimal(patterns: vskPatterns, in: raw)
        if explicitVSK != nil { confidence += 0.15 }

        // ── VSK category & final net/vsk amounts ──────────────────────────
        let (vskCategory, vskRate, netAmount, vskAmount) = deriveVSK(
            raw: raw,
            total: total,
            explicitVSK: explicitVSK
        )

        // ── Business kennitala (vendor footer, not personal) ──────────────
        let vendorKennitala = extractBusinessKennitala(from: raw)
        if vendorKennitala != nil { confidence += 0.10 }

        // ── Date ──────────────────────────────────────────────────────────
        let receiptDatePatterns: [String] = [
            #"(\d{1,2}\.\d{1,2}\.\d{4})"#,
            #"(\d{4}-\d{2}-\d{2})"#,
            #"(\d{1,2}/\d{1,2}/\d{2,4})"#,
        ]
        let dateRaw = firstString(patterns: receiptDatePatterns, in: raw)
        let transactionDate = parseDate(dateRaw) ?? Date()
        if dateRaw != nil { confidence += 0.10 }

        // ── Vendor name ───────────────────────────────────────────────────
        let vendorName = extractReceiptVendorName(lines)

        return ExtractedTransaction(
            vendorName: vendorName,
            vendorKennitala: vendorKennitala,
            currency: "ISK",
            totalAmountISK: total,
            netAmountISK: netAmount,
            vskAmountISK: vskAmount,
            vskCategory: vskCategory,
            vskRate: vskRate,
            lineItems: nil,
            transactionDate: transactionDate,
            aiConfidence: min(max(confidence, 0.15), 0.88),
            sourceDocumentType: docType,
            notes: notes.isEmpty ? nil : notes.joined(separator: "; "),
            grossPayISK: nil,
            taxWithheldISK: nil
        )
    }

    // MARK: - VSK derivation

    private func deriveVSK(
        raw: String,
        total: Decimal,
        explicitVSK: Decimal?
    ) -> (category: VSKCategory, rate: Decimal, net: Decimal, vsk: Decimal) {

        let lower = raw.lowercased()

        // Exempt check
        let exemptKeywords = ["sjúkraþjónusta", "tryggingar", "fjármálaþjónusta",
                              "íbúðarleiga", "insurance", "healthcare", "leiga"]
        if exemptKeywords.contains(where: { lower.contains($0) }) {
            return (.exempt0, Decimal(0), total, Decimal(0))
        }

        // Determine rate
        let has24 = lower.contains("24%") || lower.contains("24 %")
        let has11 = lower.contains("11%") || lower.contains("11 %")
        let reducedKeywords = ["matur", "matvæli", "dagvörur", "veitingastaður",
                               "veitingar", "hótel", "gisting", "bókaverslun",
                               "blaðsala", "rafmagn", "hiti", "food", "hotel",
                               "restaurant", "grocery", "groceries"]
        let hasReduced = reducedKeywords.contains(where: { lower.contains($0) })

        let rate: Decimal
        let category: VSKCategory
        if has11 || (hasReduced && !has24) {
            rate = Decimal(string: "0.11")!
            category = .reduced11
        } else {
            rate = Decimal(string: "0.24")!
            category = .standard24
        }

        // Use explicit VSK if found and plausible
        if let vsk = explicitVSK, vsk > 0, vsk < total {
            let net = total - vsk
            return (category, rate, net, vsk)
        }

        // Back-calculate from total: net = total / (1 + rate)
        let divisor = NSDecimalNumber(decimal: Decimal(1) + rate)
        let handler = NSDecimalNumberHandler(
            roundingMode: .plain, scale: 0,
            raiseOnExactness: false, raiseOnOverflow: false,
            raiseOnUnderflow: false, raiseOnDivideByZero: false
        )
        let net = NSDecimalNumber(decimal: total).dividing(by: divisor, withBehavior: handler).decimalValue
        let vsk = total - net
        return (category, rate, net, vsk)
    }

    // MARK: - Employer name (payslip, security-sensitive)

    /// Returns the employer's company name only when clearly identifiable by a
    /// legal-form suffix. Returns nil rather than guess — caller fills in a
    /// safe placeholder. NEVER returns an employee's personal name.
    private func extractEmployerName(lines: [String], raw: String) -> String? {
        // Look for explicitly labelled employer lines first
        let labeledPatterns: [String] = [
            #"(?:vinnuveitandi|fyrirtæki|launagreiðandi|employer)\s*[:\-–]\s*(.{3,70})"#,
        ]
        if let labeled = firstString(patterns: labeledPatterns, in: raw) {
            return labeled.trimmingCharacters(in: .whitespaces)
        }

        // Scan early lines for a company name (must contain a legal-form suffix)
        let companyIndicators = ["ehf", "hf.", " sf.", " ohf.", "ses.", " slhf",
                                 "ráðgjöf", "þjónusta", "verslun", "samtök",
                                 "stofnun", "ríkis", "sveit", "ltd", "corp",
                                 "solutions", "services", "inc."]
        for line in lines.prefix(10) {
            let lower = line.lowercased()
            if companyIndicators.contains(where: { lower.contains($0) }),
               line.count >= 4, line.count <= 80 {
                return line
            }
        }
        return nil
    }

    // MARK: - Receipt vendor name

    /// The vendor name on Icelandic receipts is almost always the first
    /// non-numeric, non-date line near the top.
    private func extractReceiptVendorName(_ lines: [String]) -> String {
        for line in lines.prefix(5) {
            guard !line.isEmpty, line.count >= 3 else { continue }
            // Skip lines that look like dates or pure numbers
            let firstChar = line.unicodeScalars.first!
            guard !CharacterSet.decimalDigits.contains(firstChar) else { continue }
            // Skip lines that are obviously headers/labels
            let lower = line.lowercased()
            let isHeader = ["kvittun", "reikningur", "receipt", "invoice",
                            "dagsetning", "date", "tími", "time"].contains(where: { lower == $0 })
            guard !isHeader else { continue }
            return line
        }
        return "Óþekktur söluaðili"
    }

    // MARK: - Business kennitala

    /// Returns the LAST kennitala found in the text, which on Icelandic
    /// receipts is typically the company's registration number in the footer.
    /// Always returns nil for payslips — called only from receipt path.
    private func extractBusinessKennitala(from text: String) -> String? {
        let pattern = #"\b(\d{6}-?\d{4})\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
        guard let last = matches.last else { return nil }
        let raw = ns.substring(with: last.range(at: 1)).replacingOccurrences(of: "-", with: "")
        // Exclude obvious non-kennitala matches (e.g. all-zero or sequential)
        guard raw != "0000000000", raw.count == 10 else { return nil }
        return raw
    }

    // MARK: - Date parsing

    private func parseDate(_ s: String?) -> Date? {
        guard let s else { return nil }

        // ISO 8601
        if let d = ExtractedTransaction.dateOnlyFormatter.date(from: s) { return d }

        // DD.MM.YYYY, DD/MM/YYYY, DD-MM-YYYY
        let sep: [Character] = [".", "/", "-"]
        for ch in sep {
            let parts = s.split(separator: ch).map(String.init)
            guard parts.count >= 3 else { continue }
            let day = parts[0].count == 1 ? "0\(parts[0])" : parts[0]
            let month = parts[1].count == 1 ? "0\(parts[1])" : parts[1]
            let year = parts[2].count == 2 ? "20\(parts[2])" : parts[2]
            let iso = "\(year)-\(month)-\(day)"
            if let d = ExtractedTransaction.dateOnlyFormatter.date(from: iso) { return d }
        }
        return nil
    }

    // MARK: - Number parsing

    /// Icelandic number format: "." = thousands separator, "," = decimal.
    /// Examples: "1.234,56" → 1234.56 | "245.680" → 245680 | "680" → 680
    private func parseIcelandicDecimal(_ s: String) -> Decimal? {
        let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespaces).joined()   // remove inner spaces

        if clean.contains(",") {
            // Has decimal part — remove dot thousands seps, swap comma
            let normalized = clean
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            return Decimal(string: normalized)
        }
        // Dots only → thousands separators
        let withoutDots = clean.replacingOccurrences(of: ".", with: "")
        return Decimal(string: withoutDots)
    }

    /// Applies multiple regex patterns in order; returns the first captured
    /// group successfully parsed as a Decimal.
    private func firstDecimal(patterns: [String], in text: String) -> Decimal? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .anchorsMatchLines]
            ) else { continue }
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  match.range(at: 1).location != NSNotFound else { continue }
            let captured = ns.substring(with: match.range(at: 1))
            if let value = parseIcelandicDecimal(captured), value > 0 {
                return value
            }
        }
        return nil
    }

    /// Applies multiple regex patterns; returns the first captured group as a raw String.
    private func firstString(patterns: [String], in text: String) -> String? {
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(
                pattern: pattern,
                options: [.caseInsensitive, .anchorsMatchLines]
            ) else { continue }
            let ns = text as NSString
            let range = NSRange(location: 0, length: ns.length)
            guard let match = regex.firstMatch(in: text, range: range),
                  match.numberOfRanges > 1,
                  match.range(at: 1).location != NSNotFound else { continue }
            return ns.substring(with: match.range(at: 1))
        }
        return nil
    }

    /// Extracts all plausible ISK amounts from a block of text.
    /// Filters out numbers smaller than 10 to avoid noise (version numbers, etc.).
    private func allDecimalAmounts(in text: String) -> [Decimal] {
        let pattern = #"\b\d{1,3}(?:\.\d{3})*(?:,\d+)?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let ns = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: ns.length))
            .compactMap { parseIcelandicDecimal(ns.substring(with: $0.range)) }
            .filter { $0 >= 10 }
    }
}
