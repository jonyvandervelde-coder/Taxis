import Foundation
import SwiftUI

// MARK: - Models

enum LedgerCategory: String, Codable, CaseIterable {
    case launþegi
    case verktaki
    case heimagisting

    var displayName: String {
        switch self {
        case .launþegi:    return "Launþegi"
        case .verktaki:    return "Verktaki"
        case .heimagisting:return "Heimagisting"
        }
    }
}

struct TaxLedgerEntry: Codable, Identifiable {
    let id: String?
    let category: LedgerCategory
    let grossAmount: Double
    let dateLogged: String
    let description: String?
    let checkIn: String?
    let checkOut: String?
    let nightsCount: Int?
    let lodgingTaxPerNight: Double?
    let deductibleExpenses: Double?
    let withholdingTaxPaid: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case category
        case grossAmount          = "gross_amount"
        case dateLogged           = "date_logged"
        case description
        case checkIn              = "check_in"
        case checkOut             = "check_out"
        case nightsCount          = "nights_count"
        case lodgingTaxPerNight   = "lodging_tax_per_night"
        case deductibleExpenses   = "deductible_expenses"
        case withholdingTaxPaid   = "withholding_tax_paid"
    }
}

struct HeimagistingMetrics {
    var nightsUsed: Int    = 0
    var grossTotal: Double = 0
    var nightsRemaining: Int    = 90
    var allowanceRemaining: Double = 2_000_000
    var cliffTriggered: Bool   = false
    var capitalTaxReserve: Double? = nil

    var nightsFraction: Double { min(Double(nightsUsed) / 90.0, 1.0) }
    var incomeFraction: Double { min(grossTotal / 2_000_000, 1.0) }
}

// MARK: - Store

@MainActor
final class TaxLedgerStore: ObservableObject {
    static let shared = TaxLedgerStore()

    @Published var entries: [TaxLedgerEntry] = []
    @Published var metrics = HeimagistingMetrics()
    @Published var isLoading = false
    @Published var saveError: String?

    private init() {}

    func load() async {
        guard
            let token   = try? SupabaseSession.currentAccessToken(),
            let anonKey = try? SupabaseConfig.anonKey,
            let restURL = try? SupabaseConfig.restURL
        else { return }

        isLoading = true
        defer { isLoading = false }

        // Fetch ledger entries
        var req = URLRequest(url: restURL.appendingPathComponent("tax_ledger")
            .appending(queryItems: [URLQueryItem(name: "order", value: "date_logged.desc")]))
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey,           forHTTPHeaderField: "apikey")
        req.setValue("application/json",forHTTPHeaderField: "Accept")

        if let (data, _) = try? await URLSession.shared.data(for: req),
           let decoded = try? JSONDecoder().decode([TaxLedgerEntry].self, from: data) {
            entries = decoded
        }

        // Fetch dashboard metrics
        var mReq = URLRequest(url: restURL.appendingPathComponent("user_tax_dashboard_metrics")
            .appending(queryItems: [URLQueryItem(name: "limit", value: "1")]))
        mReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        mReq.setValue(anonKey,           forHTTPHeaderField: "apikey")
        mReq.setValue("application/json",forHTTPHeaderField: "Accept")

        if let (data, _) = try? await URLSession.shared.data(for: mReq),
           let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
           let row = arr.first {
            var m = HeimagistingMetrics()
            m.nightsUsed       = (row["total_airbnb_nights"]           as? Int)    ?? 0
            m.grossTotal       = (row["total_airbnb_gross"]            as? Double) ?? 0
            m.nightsRemaining  = (row["nights_remaining"]              as? Int)    ?? 90
            m.allowanceRemaining = (row["income_allowance_remaining"]  as? Double) ?? 2_000_000
            m.cliffTriggered   = (row["heimagisting_cliff_triggered"]  as? Bool)   ?? false
            m.capitalTaxReserve = row["dynamic_airbnb_capital_tax_reserve"] as? Double
            metrics = m
        }
    }

    func addStay(gross: Double, checkIn: Date, checkOut: Date, note: String) async {
        guard
            let token   = try? SupabaseSession.currentAccessToken(),
            let anonKey = try? SupabaseConfig.anonKey,
            let restURL = try? SupabaseConfig.restURL
        else {
            saveError = "Ekki innskráður"
            return
        }

        saveError = nil
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"

        let body: [String: Any?] = [
            "category":    "heimagisting",
            "gross_amount": gross,
            "check_in":    df.string(from: checkIn),
            "check_out":   df.string(from: checkOut),
            "description": note.isEmpty ? nil : note
        ]

        var req = URLRequest(url: restURL.appendingPathComponent("tax_ledger"))
        req.httpMethod = "POST"
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey,           forHTTPHeaderField: "apikey")
        req.setValue("application/json",forHTTPHeaderField: "Content-Type")
        req.setValue("application/json",forHTTPHeaderField: "Accept")
        req.setValue("return=minimal",  forHTTPHeaderField: "Prefer")

        do {
            req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })
            let (_, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 201 else {
                saveError = "Villa við vistun"
                return
            }
            await load()
        } catch {
            saveError = error.localizedDescription
        }
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        var c = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        c.queryItems = (c.queryItems ?? []) + queryItems
        return c.url!
    }
}
