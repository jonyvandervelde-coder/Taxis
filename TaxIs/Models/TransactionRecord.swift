//
//  TransactionRecord.swift
//  TaxÍs
//
//  Mirrors one row of the `transactions` table (taxis_schema.sql), used by
//  SupabaseTransactionRepository for insert/select/update over PostgREST.
//  Distinct from ExtractedTransaction (TaxIsModels.swift), which is only
//  the AI's output shape — this is the full persisted row, including the
//  workflow (extraction_status/confirmed_at) and audit-trail (ai_model/
//  ai_raw_response) columns the AI never sets.
//
//  Built from JSON dictionaries rather than Codable, matching how
//  ReceiptExtractionService already handles the AI provider's dynamic
//  JSON — `ai_raw_response` is an open-ended jsonb blob that doesn't fit
//  a strictly-typed Codable model.
//

import Foundation

enum ExtractionStatus: String {
    case pendingReview = "pending_review"
    case confirmed
    case rejected
}

enum TransactionRecordError: LocalizedError {
    case missingField(String)

    var errorDescription: String? {
        switch self {
        case .missingField(let field):
            return "Transaction row is missing or has an invalid value for required field '\(field)'."
        }
    }
}

struct TransactionRecord: Identifiable, Equatable {
    static func == (lhs: TransactionRecord, rhs: TransactionRecord) -> Bool {
        lhs.id == rhs.id
    }

    let id: UUID?
    let userId: UUID
    let sourceDocumentType: SourceDocumentType
    let originalTextHash: String?
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
    let aiModel: String
    let aiConfidence: Double?
    let aiRawResponse: [String: Any]
    let extractionStatus: ExtractionStatus
    let confirmedAt: Date?
    let notes: String?
    let grossPayISK: Decimal?
    let taxWithheldISK: Decimal?

    init(
        id: UUID?,
        userId: UUID,
        sourceDocumentType: SourceDocumentType,
        originalTextHash: String?,
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
        aiModel: String,
        aiConfidence: Double?,
        aiRawResponse: [String: Any],
        extractionStatus: ExtractionStatus,
        confirmedAt: Date?,
        notes: String?,
        grossPayISK: Decimal? = nil,
        taxWithheldISK: Decimal? = nil
    ) {
        self.id = id
        self.userId = userId
        self.sourceDocumentType = sourceDocumentType
        self.originalTextHash = originalTextHash
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
        self.aiModel = aiModel
        self.aiConfidence = aiConfidence
        self.aiRawResponse = aiRawResponse
        self.extractionStatus = extractionStatus
        self.confirmedAt = confirmedAt
        self.notes = notes
        self.grossPayISK = grossPayISK
        self.taxWithheldISK = taxWithheldISK
    }

    /// Builds the row to insert for a freshly extracted transaction, before
    /// it has an `id`/`created_at`/`updated_at` (the database assigns those).
    static func pendingRecord(
        userId: UUID,
        extraction: ExtractedTransaction,
        originalTextHash: String?,
        aiModel: String,
        aiRawResponse: [String: Any],
        status: ExtractionStatus = .pendingReview
    ) -> TransactionRecord {
        TransactionRecord(
            id: nil,
            userId: userId,
            sourceDocumentType: extraction.sourceDocumentType,
            originalTextHash: originalTextHash,
            vendorName: extraction.vendorName,
            vendorKennitala: extraction.vendorKennitala,
            currency: extraction.currency,
            totalAmountISK: extraction.totalAmountISK,
            netAmountISK: extraction.netAmountISK,
            vskAmountISK: extraction.vskAmountISK,
            vskCategory: extraction.vskCategory,
            vskRate: extraction.vskRate,
            lineItems: extraction.lineItems,
            transactionDate: extraction.transactionDate,
            aiModel: aiModel,
            aiConfidence: extraction.aiConfidence,
            aiRawResponse: aiRawResponse,
            extractionStatus: status,
            confirmedAt: nil,
            notes: extraction.notes,
            grossPayISK: extraction.grossPayISK,
            taxWithheldISK: extraction.taxWithheldISK
        )
    }

    /// Decodes a row as returned by PostgREST (`GET` or `POST/PATCH ...
    /// Prefer: return=representation`).
    init(fromPostgRESTRow json: [String: Any]) throws {
        self.id = (json["id"] as? String).flatMap(UUID.init(uuidString:))

        let userIdString = try TransactionRecord.requireString(json, "user_id")
        guard let userId = UUID(uuidString: userIdString) else {
            throw TransactionRecordError.missingField("user_id")
        }
        self.userId = userId

        let sourceTypeRaw = try TransactionRecord.requireString(json, "source_document_type")
        self.sourceDocumentType = SourceDocumentType(rawValue: sourceTypeRaw) ?? .receipt
        self.originalTextHash = json["original_text_hash"] as? String

        self.vendorName = try TransactionRecord.requireString(json, "vendor_name")
        self.vendorKennitala = json["vendor_kennitala"] as? String
        self.currency = try TransactionRecord.requireString(json, "currency")
        self.totalAmountISK = try TransactionRecord.decimal(from: json, key: "total_amount_isk")
        self.netAmountISK = try TransactionRecord.decimal(from: json, key: "net_amount_isk")
        self.vskAmountISK = try TransactionRecord.decimal(from: json, key: "vsk_amount_isk")

        let vskCategoryRaw = try TransactionRecord.requireString(json, "vsk_category")
        guard let vskCategory = VSKCategory(rawValue: vskCategoryRaw) else {
            throw TransactionRecordError.missingField("vsk_category")
        }
        self.vskCategory = vskCategory
        self.vskRate = try TransactionRecord.decimal(from: json, key: "vsk_rate")

        if let lineItemsJSON = json["line_items"] as? [[String: Any]] {
            self.lineItems = try lineItemsJSON.map { itemJSON -> TransactionLineItem in
                let description = try TransactionRecord.requireString(itemJSON, "description")
                let amount = try TransactionRecord.decimal(from: itemJSON, key: "amount_isk")
                guard
                    let categoryRaw = itemJSON["vsk_category"] as? String,
                    let category = VSKCategory(rawValue: categoryRaw)
                else {
                    throw TransactionRecordError.missingField("line_items.vsk_category")
                }
                return TransactionLineItem(description: description, amountISK: amount, vskCategory: category)
            }
        } else {
            self.lineItems = nil
        }

        let dateString = try TransactionRecord.requireString(json, "transaction_date")
        guard let date = ExtractedTransaction.dateOnlyFormatter.date(from: dateString) else {
            throw TransactionRecordError.missingField("transaction_date")
        }
        self.transactionDate = date

        self.aiModel = try TransactionRecord.requireString(json, "ai_model")
        self.aiConfidence = (json["ai_confidence"] as? NSNumber)?.doubleValue
        self.aiRawResponse = (json["ai_raw_response"] as? [String: Any]) ?? [:]

        let statusRaw = try TransactionRecord.requireString(json, "extraction_status")
        guard let status = ExtractionStatus(rawValue: statusRaw) else {
            throw TransactionRecordError.missingField("extraction_status")
        }
        self.extractionStatus = status

        if let confirmedAtString = json["confirmed_at"] as? String {
            self.confirmedAt = TransactionRecord.parseTimestamp(confirmedAtString)
        } else {
            self.confirmedAt = nil
        }
        self.notes = json["notes"] as? String
        self.grossPayISK = try? TransactionRecord.decimal(from: json, key: "gross_pay_isk")
        self.taxWithheldISK = try? TransactionRecord.decimal(from: json, key: "tax_withheld_isk")
    }

    /// JSON payload for `POST`-inserting this record. Omits `id`/
    /// `created_at`/`updated_at` (DB-generated).
    func asInsertPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "user_id": userId.uuidString,
            "source_document_type": sourceDocumentType.rawValue,
            "vendor_name": vendorName,
            "currency": currency,
            "total_amount_isk": NSDecimalNumber(decimal: totalAmountISK).doubleValue,
            "net_amount_isk": NSDecimalNumber(decimal: netAmountISK).doubleValue,
            "vsk_amount_isk": NSDecimalNumber(decimal: vskAmountISK).doubleValue,
            "vsk_category": vskCategory.rawValue,
            "vsk_rate": NSDecimalNumber(decimal: vskRate).doubleValue,
            "transaction_date": ExtractedTransaction.dateOnlyFormatter.string(from: transactionDate),
            "ai_model": aiModel,
            "ai_raw_response": aiRawResponse,
            "extraction_status": extractionStatus.rawValue
        ]
        if let originalTextHash { payload["original_text_hash"] = originalTextHash }
        if let vendorKennitala { payload["vendor_kennitala"] = vendorKennitala }
        if let aiConfidence { payload["ai_confidence"] = aiConfidence }
        if let notes { payload["notes"] = notes }
        if let grossPayISK { payload["gross_pay_isk"] = NSDecimalNumber(decimal: grossPayISK).doubleValue }
        if let taxWithheldISK { payload["tax_withheld_isk"] = NSDecimalNumber(decimal: taxWithheldISK).doubleValue }
        if let lineItems {
            payload["line_items"] = lineItems.map { item in
                [
                    "description": item.description,
                    "amount_isk": NSDecimalNumber(decimal: item.amountISK).doubleValue,
                    "vsk_category": item.vskCategory.rawValue
                ] as [String: Any]
            }
        }
        return payload
    }

    // MARK: - Parsing helpers

    private static func requireString(_ json: [String: Any], _ key: String) throws -> String {
        guard let value = json[key] as? String else {
            throw TransactionRecordError.missingField(key)
        }
        return value
    }

    /// PostgREST returns `numeric` columns as JSON numbers by default; this
    /// also accepts a JSON string in case the client is configured to
    /// return numerics as text (avoids float round-tripping surprises).
    private static func decimal(from json: [String: Any], key: String) throws -> Decimal {
        if let string = json[key] as? String, let value = Decimal(string: string) {
            return value
        }
        if let number = json[key] as? NSNumber {
            return number.decimalValue
        }
        throw TransactionRecordError.missingField(key)
    }

    /// `timestamptz` columns may or may not include fractional seconds
    /// depending on the value; try both before giving up.
    private static func parseTimestamp(_ string: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: string) {
            return date
        }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: string)
    }
}
