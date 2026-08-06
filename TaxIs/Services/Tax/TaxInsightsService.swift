//
//  TaxInsightsService.swift
//  TaxÍs
//
//  The "agent that has read and learned everything about accounting and
//  Skatturinn/salary rules" — a single forced-tool-use call to Claude,
//  not a conversational/multi-turn agent. The domain knowledge (tax
//  brackets, persónuafsláttur, VSK thresholds, reiknað endurgjald,
//  mileage rules) lives entirely in `systemPrompt` below, sourced from
//  this project's own docs/2026-07-20-*.md files rather than invented:
//    - annual-settlement-projection.md — bracket rates, personal credit,
//      the run-rate/annualization method, confidence-band logic
//    - notification-engine.md — persónuafsláttur ceiling (72,492/mo),
//      VSK threshold + early-warning bands, default pension match rate
//    - reiknad-endurgjald.md — category E minimums + the multi-job
//      reduction formula (floor 25%, reduce by excess over 50%)
//    - mileage-engine.md — the "never more than what was actually paid"
//      statutory cap
//
//  Calls the same kind of Edge Function proxy as ReceiptExtractionService
//  (tax-insights, not receipt-extraction) so the Anthropic key stays
//  server-side. Reuses ReceiptExtractionService's error types and
//  DashboardNotification/BasisLine (from HomeView.swift) so results plug
//  directly into the existing Home screen UI.
//
//  This is explicitly an *estimate*, grounded only in whatever
//  transactions the user has actually scanned/entered — the system
//  prompt is instructed to under-report rather than fabricate a insight
//  or figure it can't derive from the given data.
//

import Foundation

struct SettlementEstimate {
    enum Outcome: String {
        case reimbursement
        case debt
        case breakEven = "break_even"
    }

    let netPositionISK: Decimal
    let outcome: Outcome
    let confidenceBandISK: Decimal
    let monthsElapsed: Int
    let projectedAnnualCombinedTaxableISK: Decimal
    let headlineNote: String
}

struct TaxInsightsResult {
    let settlement: SettlementEstimate
    let insights: [DashboardNotification]
}

final class TaxInsightsService {
    static let shared = TaxInsightsService()

    private let model = "claude-haiku-4-5-20251001"
    private let edgeFunctionName = "tax-insights"
    private let toolName = "record_tax_insights"
    /// SF Symbols the model may pick for an insight's icon — kept to a
    /// small safelist so a bad/unexpected string can't slip an emoji or
    /// nonsense glyph into the UI; anything else falls back to a generic
    /// icon in `DashboardNotification`'s init below.
    private let allowedIcons = [
        "exclamationmark.triangle.fill",
        "banknote.fill",
        "car.fill",
        "percent",
        "checkmark.seal.fill",
        "chart.line.uptrend.xyaxis",
        "person.2.fill",
    ]

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        self.decoder = JSONDecoder()
    }

    /// - Parameters:
    ///   - transactions: the user's saved payslips/invoices/receipts —
    ///     the only ground truth this call is allowed to reason from.
    ///   - workerTypes: from OnboardingStore, gives the model the
    ///     launþegi/verktaki/both context needed to decide which rules
    ///     (reiknað endurgjald, VSK threshold) even apply.
    func generateInsights(
        transactions: [TransactionRecord],
        workerTypes: Set<WorkerType>
    ) async throws -> TaxInsightsResult {
        guard !transactions.isEmpty else {
            throw ReceiptExtractionError.emptyInputText
        }

        let accessToken = try SupabaseSession.currentAccessToken()
        let requestBody = try buildRequestBody(transactions: transactions, workerTypes: workerTypes)
        let urlRequest = try buildURLRequest(accessToken: accessToken, body: requestBody)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ReceiptExtractionError.invalidHTTPResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw ReceiptExtractionError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        return try parseResult(from: data)
    }

    // MARK: - Request construction

    private func buildURLRequest(accessToken: String, body: Data) throws -> URLRequest {
        let url = try SupabaseConfig.functionsURL.appendingPathComponent(edgeFunctionName)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 45
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(try SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func buildRequestBody(transactions: [TransactionRecord], workerTypes: Set<WorkerType>) throws -> Data {
        let transactionSummaries: [[String: Any]] = transactions.map { record in
            var summary: [String: Any] = [
                "vendor_name": record.vendorName,
                "source_document_type": record.sourceDocumentType.rawValue,
                "transaction_date": ExtractedTransaction.dateOnlyFormatter.string(from: record.transactionDate),
                "total_amount_isk": NSDecimalNumber(decimal: record.totalAmountISK).doubleValue,
                "net_amount_isk": NSDecimalNumber(decimal: record.netAmountISK).doubleValue,
                "vsk_amount_isk": NSDecimalNumber(decimal: record.vskAmountISK).doubleValue,
                "vsk_category": record.vskCategory.rawValue,
            ]
            if let notes = record.notes, !notes.isEmpty {
                summary["notes"] = notes
            }
            return summary
        }

        let userContent: [String: Any] = [
            "worker_types": workerTypes.map(\.rawValue).sorted(),
            "transactions": transactionSummaries,
        ]
        let userContentData = try JSONSerialization.data(withJSONObject: userContent, options: [.sortedKeys])
        let userContentString = String(data: userContentData, encoding: .utf8) ?? "{}"

        let payload: [String: Any] = [
            "model": model,
            "max_tokens": 2048,
            "temperature": 0,
            "system": systemPrompt,
            "tools": [toolSchema],
            "tool_choice": ["type": "tool", "name": toolName],
            "messages": [
                [
                    "role": "user",
                    "content": "User's worker type(s) and saved transactions (JSON):\n\(userContentString)",
                ]
            ],
        ]
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }

    private var systemPrompt: String {
        """
        You are TaxÍs's built-in accounting analyst for Icelandic personal \
        income tax (Skatturinn rules). You are given one user's worker \
        type(s) (launþegi = employee, verktaki = self-employed contractor, \
        or both) and the full list of transactions (payslips, invoices, \
        receipts) they have scanned or entered into the app. Using ONLY \
        the rules below and the given transactions, call the \
        \(toolName) tool once with a rough settlement estimate and up to \
        4 concrete, personalized insights.

        Rules you must apply (these are the only tax facts you may use —
        never invent a rate, threshold, or figure not listed here or not
        derivable from the given transactions):

        1. Monthly combined (state + municipal) income tax brackets:
           - Up to 498,122 ISK/month: 31.49%
           - 498,122–1,398,450 ISK/month: 37.99%
           - Above 1,398,450 ISK/month: 46.29%
           For an annual projection, annualize these ceilings ×12 — this \
           is verified sound (the annual and monthly rates are the same \
           system at different granularities), not a shortcut.
        2. Personal tax credit (persónuafsláttur): 72,492 ISK/month per \
           person, 869,898 ISK/year. If payslips show TWO OR MORE distinct \
           employer names in the same month each having taxable payslip \
           income, that is a "multi-employer credit leak" risk — both \
           employers likely apply the personal credit in full, so more of \
           it is being used than the person is entitled to, meaning a debt \
           accumulates. Only flag this if you can actually see 2+ distinct \
           employer vendor names with payslip income in an overlapping \
           period in the given transactions.
        3. VSK (VAT) registration threshold for verktaki income: \
           2,000,000 ISK rolling 12-month revenue from invoices/self-\
           employed income. Early-warning bands at 1,750,000 (87%) and \
           1,950,000 (97.5%). Only flag if the user has verktaki income \
           (invoices) summing meaningfully toward this.
        4. Pension (lífeyrissjóður/séreignarsparnaður) employer match: if \
           a payslip's notes mention 0% or no supplemental pension \
           savings, flag that an employer match (assume 4% of gross salary \
           if no other rate is known) may be going unclaimed. Only flag \
           this if a payslip's notes actually mention pension percentage — \
           do not assume it applies to every payslip.
        5. Reiknað endurgjald (verktaki self-assessed minimum wage) — \
           category E (solo/unskilled work, drivers, care work — the most \
           common category for this app's users) monthly minimums: E1 \
           886,000 · E2 702,000 · E3 816,000 · E4 651,000 (651,000 × 0.85 \
           = 553,350 if genuinely working alone) · E9 472,000 (first-year \
           reduced rate). If the user also holds a fixed paid job (has \
           payslip income) in the same month, the verktaki minimum can be \
           reduced: adjustedMinimum = max(0.25 × V, 1.5 × V − W), where V \
           is the category minimum and W is that month's other job \
           income — never below 25% of V. Only flag under-declared \
           reiknað endurgjald if verktaki income in a month looks clearly \
           below the (possibly-adjusted) floor for a plausible category.
        6. Mileage/ökutækjastyrkur: if a payslip's notes mention a taxed \
           vehicle allowance, flag that logging trips in a mileage log \
           could recover part of it as a deduction — but the deduction can \
           never exceed what was actually paid per km, so never state an \
           exact recovery amount, only that logging trips could help.

        Settlement estimate method: extrapolate a run-rate from however \
        many months of transactions exist (fewer months = wider \
        confidence band — set confidence_band_isk higher when \
        months_elapsed is low), apply the brackets and personal credit \
        above, and net against amounts already reflected as tax/VSK on the \
        given transactions. Be explicit in headline_note that this is a \
        rough estimate based on {months_elapsed} of 12 months of data.

        If the given transactions don't support a confident estimate or \
        any insight at all (e.g. only one or two transactions), return \
        fewer insights (even zero) and a wide confidence band — do not \
        fabricate figures or insights to fill out the response. Never \
        adopt a "you owe money, bad news" tone — frame everything as \
        actionable ("here's what to check/do next"), per this app's \
        design system.

        Language note: In Icelandic output, NEVER use the term         "Vangreiddur skattur". When referring to a withholding tax         shortfall, always use the more cautious phrase "Áætlaður         mismunur á staðgreiðslu" and precede any figure with         "Samkvæmt skráðum upplýsingum" to make the estimate nature         clear — never state a shortfall as fact.
        """
    }

    private var toolSchema: [String: Any] {
        [
            "name": toolName,
            "description": "Records a rough Icelandic tax settlement estimate and personalized insights derived only from the given transactions.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "net_position_isk": ["type": "number", "description": "Positive = projected reimbursement, negative = projected debt."],
                    "outcome": ["type": "string", "enum": ["reimbursement", "debt", "break_even"]],
                    "confidence_band_isk": ["type": "number", "description": "± range around net_position_isk; wider with fewer months of data."],
                    "months_elapsed": ["type": "integer", "description": "Distinct months represented in the given transactions, 1-12."],
                    "projected_annual_combined_taxable_isk": ["type": "number", "description": "Extrapolated full-year taxable income, for the bracket chart."],
                    "headline_note": ["type": "string", "description": "Short caption, e.g. 'Estimate based on 3 of 12 months logged.'"],
                    "insights": [
                        "type": "array",
                        "maxItems": 4,
                        "items": [
                            "type": "object",
                            "properties": [
                                "id": ["type": "string"],
                                "icon": ["type": "string", "enum": allowedIcons],
                                "title": ["type": "string"],
                                "preview": ["type": "string", "description": "One-line summary shown in the list."],
                                "body": ["type": "string", "description": "Full explanation shown when tapped."],
                                "cta": ["type": "string", "description": "Action button label."],
                                "basis": [
                                    "type": "array",
                                    "items": [
                                        "type": "object",
                                        "properties": [
                                            "label": ["type": "string"],
                                            "value": ["type": "string"],
                                        ],
                                        "required": ["label", "value"],
                                    ],
                                ],
                            ],
                            "required": ["id", "icon", "title", "preview", "body", "cta"],
                        ],
                    ],
                ],
                "required": [
                    "net_position_isk", "outcome", "confidence_band_isk", "months_elapsed",
                    "projected_annual_combined_taxable_isk", "headline_note", "insights",
                ],
            ],
        ]
    }

    // MARK: - Response parsing

    private func parseResult(from data: Data) throws -> TaxInsightsResult {
        guard
            let topLevel = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = topLevel["content"] as? [[String: Any]],
            let toolUseBlock = content.first(where: { ($0["type"] as? String) == "tool_use" && ($0["name"] as? String) == toolName }),
            let input = toolUseBlock["input"] as? [String: Any]
        else {
            throw ReceiptExtractionError.noToolUseBlockInResponse
        }

        guard
            let netPosition = input["net_position_isk"] as? NSNumber,
            let outcomeRaw = input["outcome"] as? String,
            let outcome = SettlementEstimate.Outcome(rawValue: outcomeRaw),
            let confidenceBand = input["confidence_band_isk"] as? NSNumber,
            let monthsElapsed = input["months_elapsed"] as? Int,
            let projectedAnnual = input["projected_annual_combined_taxable_isk"] as? NSNumber,
            let headlineNote = input["headline_note"] as? String
        else {
            throw ReceiptExtractionError.decodingFailed(
                underlying: NSError(domain: "TaxInsightsService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing required settlement fields"])
            )
        }

        let settlement = SettlementEstimate(
            netPositionISK: netPosition.decimalValue,
            outcome: outcome,
            confidenceBandISK: confidenceBand.decimalValue,
            monthsElapsed: monthsElapsed,
            projectedAnnualCombinedTaxableISK: projectedAnnual.decimalValue,
            headlineNote: headlineNote
        )

        let insightsRaw = (input["insights"] as? [[String: Any]]) ?? []
        let insights = insightsRaw.compactMap { insight -> DashboardNotification? in
            guard
                let id = insight["id"] as? String,
                let title = insight["title"] as? String,
                let preview = insight["preview"] as? String,
                let body = insight["body"] as? String,
                let cta = insight["cta"] as? String
            else {
                return nil
            }
            let rawIcon = insight["icon"] as? String ?? ""
            let icon = allowedIcons.contains(rawIcon) ? rawIcon : "info.circle.fill"
            let tint = icon == "exclamationmark.triangle.fill" ? TaxIsTheme.red : TaxIsTheme.mint
            let basisRaw = (insight["basis"] as? [[String: Any]]) ?? []
            let basis = basisRaw.compactMap { line -> BasisLine? in
                guard let label = line["label"] as? String, let value = line["value"] as? String else { return nil }
                return BasisLine(label: label, value: value)
            }

            return DashboardNotification(
                id: id,
                icon: icon,
                iconBg: tint.opacity(0.15),
                iconTint: tint,
                title: title,
                preview: preview,
                body: body,
                cta: cta,
                basis: basis
            )
        }

        return TaxInsightsResult(settlement: settlement, insights: insights)
    }
}
