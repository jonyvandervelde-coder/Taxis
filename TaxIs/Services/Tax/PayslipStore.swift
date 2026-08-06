//
//  PayslipStore.swift
//  TaxÍs
//
//  Single source of truth for confirmed payslip records from the Supabase
//  `transactions` table for the currently selected month. Injected as an
//  environment object from ContentView so every tab can read it.
//
//  Design contract:
//   • OCR / manual-entry write once — via TransactionConfirmationView.save().
//   • This store reads only. It never re-triggers OCR or clears state on launch.
//   • On app launch and every time HomeView appears, refresh(month:) is called.
//   • If no session token is present the refresh is silently skipped.
//

import Foundation

@MainActor
final class PayslipStore: ObservableObject {

    /// All payslip records fetched for the currently loaded month.
    @Published private(set) var payslips: [TransactionRecord] = []
    @Published private(set) var isLoading = false

    // MARK: - Aggregates for the loaded month

    /// Sum of gross_pay_isk (falls back to total_amount_isk) across all payslips.
    var currentMonthGross: Decimal {
        payslips.reduce(Decimal(0)) { $0 + ($1.grossPayISK ?? $1.totalAmountISK) }
    }

    /// Sum of tax_withheld_isk across all payslips.
    var currentMonthTaxWithheld: Decimal {
        payslips.reduce(Decimal(0)) { $0 + ($1.taxWithheldISK ?? 0) }
    }

    /// Sum of net pay (total_amount_isk) across all payslips.
    var currentMonthNet: Decimal {
        payslips.reduce(Decimal(0)) { $0 + $1.totalAmountISK }
    }

    // MARK: - Load

    /// Fetches all payslip-type transactions for the given month key
    /// ("yyyy-MM", e.g. "2026-08"), scoped to the signed-in user via RLS.
    /// Pass nil to use the current calendar month.
    /// Silently no-ops when no valid session token is available.
    func refresh(month: String? = nil) async {
        guard (try? SupabaseSession.currentAccessToken()) != nil else { return }
        let target = month ?? SalariedJobStore.currentMonth()
        isLoading = true
        defer { isLoading = false }
        do {
            payslips = try await SupabaseTransactionRepository.shared.fetchPayslips(month: target)
        } catch {
            // Degrade silently — HomeView shows "—" when currentMonthGross == 0.
        }
    }
}
