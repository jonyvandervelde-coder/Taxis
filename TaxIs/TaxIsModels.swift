//
//  TaxIsModels.swift
//  TaxÍs
//
//  Data models for the AI receipt/invoice extraction pipeline.
//  These mirror the `transactions` / `vsk_categories` tables defined in
//  taxis_schema.sql, so a decoded ExtractedTransaction can be persisted
//  to the backend with no field-mapping guesswork.
//

import Foundation

// MARK: - VSK Category

/// Icelandic VAT ("virðisaukaskattur") categories. Raw values match the
/// `vsk_categories.code` column in taxis_schema.sql exactly, so this enum
/// can round-trip directly to/from the database and the AI JSON payload.
enum VSKCategory: String, Codable, CaseIterable {
    case standard24 = "standard_24"
    case reduced11 = "reduced_11"
    case exempt0 = "exempt_0"

    /// The VAT rate as a decimal fraction (0.24, 0.11, 0.00).
    var rate: Decimal {
        switch self {
        case .standard24: return Decimal(string: "0.24")!
        case .reduced11: return Decimal(string: "0.11")!
        case .exempt0: return Decimal(0)
        }
    }

    var displayNameIcelandic: String {
        switch self {
        case .standard24: return "Almennt þrep (24%)"
        case .reduced11: return "Lægra þrep (11%)"
        case .exempt0: return "Undanþegið VSK (0%)"
        }
    }

    var displayNameEnglish: String {
        switch self {
        case .standard24: return "Standard rate (24%)"
        case .reduced11: return "Reduced rate (11%)"
        case .exempt0: return "VAT-exempt (0%)"
        }
    }
}

// MARK: - Source document type

enum SourceDocumentType: String, Codable {
    case receipt
    case invoice
    case payslip
}

// MARK: - Line item

/// Optional itemized breakdown, used when a single receipt mixes VSK
/// rates (e.g. a supermarket receipt: groceries at 11%, household
/// goods at 24%). Matches the `line_items` jsonb column.
struct TransactionLineItem: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    let description: String
    let amountISK: Decimal
    let vskCategory: VSKCategory

    enum CodingKeys: String, CodingKey {
        case description
        case amountISK = "amount_isk"
        case vskCategory = "vsk_category"
    }

    // `id` is client-side only — never sent to or received from the AI model.
    init(description: String, amountISK: Decimal, vskCategory: VSKCategory) {
        self.description = description
        self.amountISK = amountISK
        self.vskCategory = vskCategory
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.description = try container.decode(String.self, forKey: .description)
        self.amountISK = try container.decode(Decimal.self, forKey: .amountISK)
        self.vskCategory = try container.decode(VSKCategory.self, forKey: .vskCategory)
        self.id = UUID()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(description, forKey: .description)
        try container.encode(amountISK, forKey: .amountISK)
        try container.encode(vskCategory, forKey: .vskCategory)
    }
}

// MARK: - Extracted transaction (the clean JSON payload)

/// The structured result of sending raw receipt/invoice text to the AI
/// model. This is the exact shape the model is instructed to return
/// (see `ReceiptExtractionService.buildToolSchema()`), and it maps
/// 1:1 onto the `transactions` table columns for persistence.
struct ExtractedTransaction: Codable, Equatable {
    let vendorName: String
    let vendorKennitala: String?
    let currency: String
    let totalAmountISK: Decimal
    let netAmountISK: Decimal
    let vskAmountISK: Decimal
    let vskCategory: VSKCategory
    let vskRate: Decimal
    let lineItems: [TransactionLineItem]?
    let transactionDate: Date
    let aiConfidence: Double
    let sourceDocumentType: SourceDocumentType
    let notes: String?
    /// Payslip only: gross salary before all deductions (Laun alls / bruttólaun).
    let grossPayISK: Decimal?
    /// Payslip only: income tax withheld at source (Staðgreiðsla).
    let taxWithheldISK: Decimal?

    enum CodingKeys: String, CodingKey {
        case vendorName = "vendor_name"
        case vendorKennitala = "vendor_kennitala"
        case currency
        case totalAmountISK = "total_amount_isk"
        case netAmountISK = "net_amount_isk"
        case vskAmountISK = "vsk_amount_isk"
        case vskCategory = "vsk_category"
        case vskRate = "vsk_rate"
        case lineItems = "line_items"
        case transactionDate = "transaction_date"
        case aiConfidence = "ai_confidence"
        case sourceDocumentType = "source_document_type"
        case notes
        case grossPayISK = "gross_pay_isk"
        case taxWithheldISK = "tax_withheld_isk"
    }

    init(
        vendorName: String,
        vendorKennitala: String?,
        currency: String,
        totalAmountISK: Decimal,
        netAmountISK: Decimal,
        vskAmountISK: Decimal,
        vskCategory: VSKCategory,
        vskRate: Decimal,
        lineItems: [TransactionLineItem]?,
        transactionDate: Date,
        aiConfidence: Double,
        sourceDocumentType: SourceDocumentType,
        notes: String?,
        grossPayISK: Decimal? = nil,
        taxWithheldISK: Decimal? = nil
    ) {
        self.vendorName = vendorName
        self.vendorKennitala = vendorKennitala
        self.currency = currency
        self.totalAmountISK = totalAmountISK
        self.netAmountISK = netAmountISK
        self.vskAmountISK = vskAmountISK
        self.vskCategory = vskCategory
        self.vskRate = vskRate
        self.lineItems = lineItems
        self.transactionDate = transactionDate
        self.aiConfidence = aiConfidence
        self.sourceDocumentType = sourceDocumentType
        self.notes = notes
        self.grossPayISK = grossPayISK
        self.taxWithheldISK = taxWithheldISK
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.vendorName = try container.decode(String.self, forKey: .vendorName)
        self.vendorKennitala = try container.decodeIfPresent(String.self, forKey: .vendorKennitala)
        self.currency = try container.decodeIfPresent(String.self, forKey: .currency) ?? "ISK"
        self.totalAmountISK = try container.decode(Decimal.self, forKey: .totalAmountISK)
        self.netAmountISK = try container.decode(Decimal.self, forKey: .netAmountISK)
        self.vskAmountISK = try container.decode(Decimal.self, forKey: .vskAmountISK)
        self.vskCategory = try container.decode(VSKCategory.self, forKey: .vskCategory)
        self.vskRate = try container.decode(Decimal.self, forKey: .vskRate)
        self.lineItems = try container.decodeIfPresent([TransactionLineItem].self, forKey: .lineItems)
        self.aiConfidence = try container.decode(Double.self, forKey: .aiConfidence)
        self.sourceDocumentType = try container.decode(SourceDocumentType.self, forKey: .sourceDocumentType)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.grossPayISK = try container.decodeIfPresent(Decimal.self, forKey: .grossPayISK)
        self.taxWithheldISK = try container.decodeIfPresent(Decimal.self, forKey: .taxWithheldISK)

        // transaction_date arrives as "YYYY-MM-DD" from the AI model.
        let dateString = try container.decode(String.self, forKey: .transactionDate)
        guard let parsedDate = ExtractedTransaction.dateOnlyFormatter.date(from: dateString) else {
            throw DecodingError.dataCorruptedError(
                forKey: .transactionDate,
                in: container,
                debugDescription: "Expected date in YYYY-MM-DD format, got '\(dateString)'"
            )
        }
        self.transactionDate = parsedDate
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(vendorName, forKey: .vendorName)
        try container.encodeIfPresent(vendorKennitala, forKey: .vendorKennitala)
        try container.encode(currency, forKey: .currency)
        try container.encode(totalAmountISK, forKey: .totalAmountISK)
        try container.encode(netAmountISK, forKey: .netAmountISK)
        try container.encode(vskAmountISK, forKey: .vskAmountISK)
        try container.encode(vskCategory, forKey: .vskCategory)
        try container.encode(vskRate, forKey: .vskRate)
        try container.encodeIfPresent(lineItems, forKey: .lineItems)
        try container.encode(aiConfidence, forKey: .aiConfidence)
        try container.encode(sourceDocumentType, forKey: .sourceDocumentType)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encodeIfPresent(grossPayISK, forKey: .grossPayISK)
        try container.encodeIfPresent(taxWithheldISK, forKey: .taxWithheldISK)
        let dateString = ExtractedTransaction.dateOnlyFormatter.string(from: transactionDate)
        try container.encode(dateString, forKey: .transactionDate)
    }

    static let dateOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Atlantic/Reykjavik")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    /// Cross-checks total = net + VSK within a 1 ISK rounding tolerance,
    /// mirroring the `chk_amounts_consistent` constraint in taxis_schema.sql.
    /// The AI model can be wrong; this catches arithmetic that doesn't add up
    /// before it ever reaches the user's confirmation screen.
    var isArithmeticallyConsistent: Bool {
        let tolerance = Decimal(string: "1.00")!
        let computedTotal = netAmountISK + vskAmountISK
        return abs(totalAmountISK - computedTotal) <= tolerance
    }

    /// Cross-checks that vsk_rate matches the declared vsk_category's
    /// canonical rate. Catches cases where the model picks a category
    /// label but computes with the wrong percentage.
    var isCategoryRateConsistent: Bool {
        vskRate == vskCategory.rate
    }
}
