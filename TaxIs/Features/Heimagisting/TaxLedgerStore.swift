import Foundation
import SwiftUI

// MARK: - Models

enum LedgerCategory: String, Codable, CaseIterable {
    case launþegi
    case verktaki
    case heimagisting

    var displayName: String {
        switch self {
        case .launþegi:     return "Launþegi"
        case .verktaki:     return "Verktaki"
        case .heimagisting: return "Heimagisting"
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
        case grossAmount        = "gross_amount"
        case dateLogged         = "date_logged"
        case description
        case checkIn            = "check_in"
        case checkOut           = "check_out"
        case nightsCount        = "nights_count"
        case lodgingTaxPerNight = "lodging_tax_per_night"
        case deductibleExpenses = "deductible_expenses"
        case withholdingTaxPaid = "withholding_tax_paid"
    }
}

struct HeimagistingMetrics {
    var nightsUsed: Int         = 0
    var grossTotal: Double      = 0
    var nightsRemaining: Int    = 90
    var allowanceRemaining: Double = 2_000_000
    var cliffTriggered: Bool    = false
    var capitalTaxReserve: Double? = nil

    var nightsFraction: Double { min(Double(nightsUsed) / 90.0, 1.0) }
    var incomeFraction: Double { min(grossTotal / 2_000_000, 1.0) }
}

// MARK: - Store

@MainActor
final class TaxLedgerStore: ObservableObject {
    static let shared = TaxLedgerStore()

    @Published var entries:     [TaxLedgerEntry] = []
    @Published var metrics      = HeimagistingMetrics()
    @Published var isLoading    = false
    @Published var saveError:   String?
    @Published var needsSignIn  = false

    private init() {}

    func load() async {
        guard
            let anonKey = try? SupabaseConfig.anonKey,
            let restURL = try? SupabaseConfig.restURL
        else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let token = try await validToken()

            // Ledger entries
            var req = URLRequest(url: restURL.appendingPathComponent("tax_ledger")
                .appending(queryItems: [URLQueryItem(name: "order", value: "date_logged.desc")]))
            auth(&req, token: token, anonKey: anonKey)
            let (ledgerData, ledgerResp) = try await URLSession.shared.data(for: req)
            if (ledgerResp as? HTTPURLResponse)?.statusCode == 401 {
                try await handleExpired(anonKey: anonKey, restURL: restURL)
                return
            }
            if let decoded = try? JSONDecoder().decode([TaxLedgerEntry].self, from: ledgerData) {
                entries = decoded
            }

            // Dashboard metrics
            var mReq = URLRequest(url: restURL.appendingPathComponent("user_tax_dashboard_metrics")
                .appending(queryItems: [URLQueryItem(name: "limit", value: "1")]))
            auth(&mReq, token: token, anonKey: anonKey)
            let (metaData, metaResp) = try await URLSession.shared.data(for: mReq)
            if (metaResp as? HTTPURLResponse)?.statusCode == 401 { return }
            if let arr = try? JSONSerialization.jsonObject(with: metaData) as? [[String: Any]],
               let row = arr.first {
                metrics = parseMetrics(row)
            }
        } catch SupabaseSessionError.missingRefreshToken, SupabaseSessionError.missingAccessToken {
            needsSignIn = true
        } catch {}
    }

    func addStay(gross: Double, checkIn: Date, checkOut: Date, note: String) async {
        guard
            let anonKey = try? SupabaseConfig.anonKey,
            let restURL = try? SupabaseConfig.restURL
        else { saveError = "Stillingar vantar"; return }

        saveError = nil

        do {
            let token = try await validToken()
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            // nights_count is a GENERATED column (check_out - check_in); DB computes it automatically.
            let body: [String: Any?] = [
                "category":    "heimagisting",
                "gross_amount": gross,
                "check_in":    df.string(from: checkIn),
                "check_out":   df.string(from: checkOut),
                "description": note.isEmpty ? nil : note
            ]

            var req = URLRequest(url: restURL.appendingPathComponent("tax_ledger"))
            req.httpMethod = "POST"
            auth(&req, token: token, anonKey: anonKey)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("return=minimal",   forHTTPHeaderField: "Prefer")
            req.httpBody = try JSONSerialization.data(withJSONObject: body.compactMapValues { $0 })

            let (_, response) = try await URLSession.shared.data(for: req)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 401 {
                needsSignIn = true
                saveError = "Ekki innskráður"
                return
            }
            guard status == 201 else {
                saveError = "Villa við vistun (\(status))"
                return
            }
            await load()
        } catch SupabaseSessionError.missingRefreshToken, SupabaseSessionError.missingAccessToken {
            needsSignIn = true
            saveError = "Ekki innskráður"
        } catch {
            saveError = error.localizedDescription
        }
    }

    // MARK: - Helpers

    private func validToken() async throws -> String {
        if let t = try? SupabaseSession.currentAccessToken() { return t }
        return try await SupabaseSession.refresh()
    }

    private func handleExpired(anonKey: String, restURL: URL) async throws {
        // Try to refresh and reload once
        _ = try await SupabaseSession.refresh()
        await load()
    }

    private func auth(_ req: inout URLRequest, token: String, anonKey: String) {
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue(anonKey,           forHTTPHeaderField: "apikey")
        req.setValue("application/json",forHTTPHeaderField: "Accept")
    }

    private func parseMetrics(_ row: [String: Any]) -> HeimagistingMetrics {
        var m = HeimagistingMetrics()
        // total_airbnb_nights may come back as Int or Double depending on Postgres numeric type
        m.nightsUsed       = (row["total_airbnb_nights"] as? Int)
                          ?? Int((row["total_airbnb_nights"] as? Double) ?? 0)
        m.grossTotal       = (row["total_airbnb_gross"] as? Double)
                          ?? Double((row["total_airbnb_gross"] as? Int) ?? 0)
        m.nightsRemaining  = (row["nights_remaining"] as? Int)
                          ?? Int((row["nights_remaining"] as? Double) ?? 90)
        m.allowanceRemaining = (row["income_allowance_remaining"] as? Double)
                            ?? Double((row["income_allowance_remaining"] as? Int) ?? 2_000_000)
        m.cliffTriggered   = (row["heimagisting_cliff_triggered"] as? Bool) ?? false
        m.capitalTaxReserve = row["dynamic_airbnb_capital_tax_reserve"] as? Double
        return m
    }
}
