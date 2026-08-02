//
//  VerktakiRevenueStore.swift
//  TaxÍs
//
//  Persists contractor gross revenue entries and tracks the rolling
//  12-month total toward the 2,000,000 ISK VSK registration threshold.
//  Same UserDefaults-local pattern as VerktakiExpenseStore.
//

import Foundation

struct VerktakiRevenueEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var description: String
    var grossRevenueISK: Decimal
    var date: Date

    init(id: UUID = UUID(), description: String, grossRevenueISK: Decimal, date: Date = Date()) {
        self.id = id
        self.description = description
        self.grossRevenueISK = grossRevenueISK
        self.date = date
    }
}

@MainActor
final class VerktakiRevenueStore: ObservableObject {
    @Published private(set) var entries: [VerktakiRevenueEntry] = []
    private let storageKey = "taxis.verktaki.revenue"
    private let calendar = Calendar.current

    init() { load() }

    func add(description: String, grossRevenueISK: Decimal) {
        entries.append(VerktakiRevenueEntry(description: description, grossRevenueISK: grossRevenueISK))
        save()
    }

    func remove(_ entry: VerktakiRevenueEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    var currentMonthEntries: [VerktakiRevenueEntry] {
        let now = Date()
        return entries
            .filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
            .sorted { $0.date > $1.date }
    }

    var currentMonthTotal: Decimal {
        currentMonthEntries.reduce(Decimal(0)) { $0 + $1.grossRevenueISK }
    }

    var rolling12MonthTotal: Decimal {
        guard let cutoff = calendar.date(byAdding: .month, value: -12, to: Date()) else {
            return entries.reduce(Decimal(0)) { $0 + $1.grossRevenueISK }
        }
        return entries.filter { $0.date >= cutoff }.reduce(Decimal(0)) { $0 + $1.grossRevenueISK }
    }

    var vskThresholdFraction: Double {
        min(1.0, NSDecimalNumber(decimal: rolling12MonthTotal).doubleValue / 2_000_000.0)
    }

    var isOverVskThreshold: Bool {
        rolling12MonthTotal >= TaxConstants.vskThreshold
    }

    var isNearVskThreshold: Bool {
        !isOverVskThreshold
        && rolling12MonthTotal >= TaxConstants.vskThreshold - TaxConstants.vskEarlyWarning
    }

    var vskRemainingISK: Decimal {
        max(Decimal(0), TaxConstants.vskThreshold - rolling12MonthTotal)
    }

    var vskOverageISK: Decimal {
        max(Decimal(0), rolling12MonthTotal - TaxConstants.vskThreshold)
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([VerktakiRevenueEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
