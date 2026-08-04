//
//  VerktakiExpenseStore.swift
//  TaxÍs
//
//  Verktaki (contractor) deductible-expense log: bensín, akstur (km),
//  sími, and anything else the user types a category + ISK amount for.
//  Unlike transactions (OCR'd, Supabase-backed), these are always
//  self-reported by the user, so they're kept as a local UserDefaults log
//  rather than a new Supabase table — the same pattern OnboardingStore
//  already uses for local-only preferences.
//
//  "Recurring" categories (see `recentCategories`) aren't a separate kind
//  of entry — they're just this month's or a past month's category+amount
//  surfaced again as a one-tap re-add, so a user who logs "Sími 5.000 kr."
//  every month doesn't have to retype it.
//

import Foundation

struct VerktakiExpenseEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var category: String
    var amountISK: Decimal
    var date: Date

    init(id: UUID = UUID(), category: String, amountISK: Decimal, date: Date = Date()) {
        self.id = id
        self.category = category
        self.amountISK = amountISK
        self.date = date
    }
}

@MainActor
final class VerktakiExpenseStore: ObservableObject {
    @Published private(set) var entries: [VerktakiExpenseEntry] = []

    private let storageKey = "taxis.verktaki.expenses"
    private let calendar = Calendar.current

    init() {
        load()
    }

    func add(category: String, amountISK: Decimal) {
        entries.append(VerktakiExpenseEntry(category: category, amountISK: amountISK))
        save()
    }

    func remove(_ entry: VerktakiExpenseEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    var entriesThisMonth: [VerktakiExpenseEntry] {
        let now = Date()
        return entries
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    var totalThisMonth: Decimal {
        entriesThisMonth.reduce(Decimal(0)) { $0 + $1.amountISK }
    }

    /// One entry per distinct category, most-recently-used amount first —
    /// what a "log it again this month" quick-add chip is built from.
    var recentCategories: [(category: String, lastAmount: Decimal)] {
        var seen = Set<String>()
        var result: [(String, Decimal)] = []
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            guard !seen.contains(entry.category) else { continue }
            seen.insert(entry.category)
            result.append((entry.category, entry.amountISK))
        }
        return result
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([VerktakiExpenseEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
