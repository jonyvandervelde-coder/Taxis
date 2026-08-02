//
//  SalariedJobStore.swift
//  TaxÍs
//
//  Persists one entry per employer per month for salaried (launþegi)
//  income, so TaxCalculationEngine can run the bracket-spillover and
//  credit-double-use checks across multiple jobs simultaneously.
//  Same UserDefaults-local pattern as VerktakiExpenseStore.
//

import Foundation

struct SalariedJobEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var employerName: String
    var grossSalaryISK: Decimal
    var taxWithheldISK: Decimal
    var pensionDeductedISK: Decimal
    /// persónuafsláttur applied by this employer this month.
    /// Default is the full monthly ceiling (72,492 kr.) — adjust down
    /// if the employer splits it with another job.
    var taxCreditUsedISK: Decimal
    var month: String  // "yyyy-MM"

    init(
        id: UUID = UUID(),
        employerName: String,
        grossSalaryISK: Decimal,
        taxWithheldISK: Decimal,
        pensionDeductedISK: Decimal,
        taxCreditUsedISK: Decimal = TaxConstants.persónuafsláttur,
        month: String = SalariedJobStore.currentMonth()
    ) {
        self.id = id
        self.employerName = employerName
        self.grossSalaryISK = grossSalaryISK
        self.taxWithheldISK = taxWithheldISK
        self.pensionDeductedISK = pensionDeductedISK
        self.taxCreditUsedISK = taxCreditUsedISK
        self.month = month
    }
}

@MainActor
final class SalariedJobStore: ObservableObject {
    @Published private(set) var entries: [SalariedJobEntry] = []
    private let storageKey = "taxis.salaried.jobs"

    init() { load() }

    nonisolated static func currentMonth() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }

    func add(_ entry: SalariedJobEntry) {
        entries.append(entry)
        save()
    }

    func remove(_ entry: SalariedJobEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    var currentMonthEntries: [SalariedJobEntry] {
        entries.filter { $0.month == Self.currentMonth() }
    }

    var currentMonthCalculation: SalariedCalculationResult? {
        let jobs = currentMonthEntries
        guard !jobs.isEmpty else { return nil }
        return TaxCalculationEngine.calculateSalaried(jobs: jobs.map {
            SalariedJobInput(
                employerName:    $0.employerName,
                grossSalaryISK:  $0.grossSalaryISK,
                taxWithheldISK:  $0.taxWithheldISK,
                pensionDeductedISK: $0.pensionDeductedISK,
                taxCreditUsedISK:   $0.taxCreditUsedISK
            )
        })
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([SalariedJobEntry].self, from: data)
        else { return }
        entries = decoded
    }
}
