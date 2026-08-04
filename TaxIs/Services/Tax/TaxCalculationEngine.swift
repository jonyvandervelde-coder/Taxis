//
//  TaxCalculationEngine.swift
//  TaxÍs
//
//  Deterministic Icelandic personal income tax engine (2026 rates).
//  Pure functions only — no UI, no ObservableObject, no side effects.
//  Constants sourced from the same project docs used by TaxInsightsService:
//    annual-settlement-projection.md → bracket rates & ceilings
//    notification-engine.md         → persónuafsláttur ceiling & VSK limit
//    reiknad-endurgjald.md          → pension & tryggingagjald rates
//

import Foundation

// MARK: - 2026 Tax Constants

enum TaxConstants {
    static let tier1Ceiling: Decimal = 498_122
    static let tier2Ceiling: Decimal = 1_398_450
    static let tier1Rate    = Decimal(string: "0.3149")!
    static let tier2Rate    = Decimal(string: "0.3799")!
    static let tier3Rate    = Decimal(string: "0.4629")!
    /// Monthly personal tax credit. If two employers both apply the full
    /// amount, the user effectively uses it twice and builds an annual debt.
    static let persónuafsláttur: Decimal = 72_492
    static let employeePensionRate      = Decimal(string: "0.04")!
    static let employerPensionMinRate   = Decimal(string: "0.115")!
    static let selfEmployedPensionRate  = Decimal(string: "0.12")!
    /// Tryggingagjald (insurance levy) for self-employed, on reiknað endurgjald.
    static let tryggingagjaldRate       = Decimal(string: "0.0635")!
    static let vskThreshold: Decimal    = 2_000_000
    static let vskEarlyWarning: Decimal = 500_000
}

// MARK: - Salaried (launþegi)

struct SalariedJobInput {
    let employerName: String
    let grossSalaryISK: Decimal
    let taxWithheldISK: Decimal
    let pensionDeductedISK: Decimal
    let taxCreditUsedISK: Decimal
}

struct SalariedCalculationResult {
    let combinedGrossISK: Decimal
    let taxableBaseISK: Decimal
    let expectedTaxISK: Decimal
    let actualTaxPaidISK: Decimal
    /// Positive = underpayment (user owes more). Negative = overpayment.
    let discrepancyISK: Decimal
    let totalCreditUsedISK: Decimal
    /// Positive = more than one employer applied the personal credit.
    let creditOveruseISK: Decimal
    let isInTier2: Bool
    let isInTier3: Bool
    let tier2OverflowISK: Decimal
}

// MARK: - Contractor (verktaki)

struct ContractorCalculationResult {
    let grossRevenueISK: Decimal
    let totalExpensesISK: Decimal
    let netIncomeISK: Decimal
    let estimatedTaxISK: Decimal
    let pensionObligationISK: Decimal
    let tryggingagjaldISK: Decimal
    let totalRetentionISK: Decimal
    /// Rounded to the nearest whole percentage point.
    let retentionPercent: Decimal
}

// MARK: - Engine

enum TaxCalculationEngine {

    static func calculateSalaried(jobs: [SalariedJobInput]) -> SalariedCalculationResult {
        let combinedGross   = jobs.reduce(Decimal(0)) { $0 + $1.grossSalaryISK }
        let combinedPension = jobs.reduce(Decimal(0)) { $0 + $1.pensionDeductedISK }
        let actualTaxPaid   = jobs.reduce(Decimal(0)) { $0 + $1.taxWithheldISK }
        let totalCredit     = jobs.reduce(Decimal(0)) { $0 + $1.taxCreditUsedISK }

        let taxableBase = max(Decimal(0), combinedGross - combinedPension)

        let rawTax: Decimal
        let isInTier2: Bool
        let isInTier3: Bool
        let tier2Overflow: Decimal

        if taxableBase <= TaxConstants.tier1Ceiling {
            rawTax = taxableBase * TaxConstants.tier1Rate
            isInTier2 = false; isInTier3 = false; tier2Overflow = 0
        } else if taxableBase <= TaxConstants.tier2Ceiling {
            rawTax = TaxConstants.tier1Ceiling * TaxConstants.tier1Rate
                + (taxableBase - TaxConstants.tier1Ceiling) * TaxConstants.tier2Rate
            isInTier2 = true; isInTier3 = false
            tier2Overflow = taxableBase - TaxConstants.tier1Ceiling
        } else {
            rawTax = TaxConstants.tier1Ceiling * TaxConstants.tier1Rate
                + (TaxConstants.tier2Ceiling - TaxConstants.tier1Ceiling) * TaxConstants.tier2Rate
                + (taxableBase - TaxConstants.tier2Ceiling) * TaxConstants.tier3Rate
            isInTier2 = true; isInTier3 = true
            tier2Overflow = taxableBase - TaxConstants.tier1Ceiling
        }

        let expectedTax   = max(Decimal(0), rawTax - TaxConstants.persónuafsláttur)
        let discrepancy   = expectedTax - actualTaxPaid
        let creditOveruse = max(Decimal(0), totalCredit - TaxConstants.persónuafsláttur)

        return SalariedCalculationResult(
            combinedGrossISK:   combinedGross,
            taxableBaseISK:     taxableBase,
            expectedTaxISK:     expectedTax,
            actualTaxPaidISK:   actualTaxPaid,
            discrepancyISK:     discrepancy,
            totalCreditUsedISK: totalCredit,
            creditOveruseISK:   creditOveruse,
            isInTier2:          isInTier2,
            isInTier3:          isInTier3,
            tier2OverflowISK:   tier2Overflow
        )
    }

    static func calculateContractor(
        grossRevenueISK: Decimal,
        totalExpensesISK: Decimal
    ) -> ContractorCalculationResult {
        let netIncome = max(Decimal(0), grossRevenueISK - totalExpensesISK)

        let rawTax: Decimal
        if netIncome <= TaxConstants.tier1Ceiling {
            rawTax = netIncome * TaxConstants.tier1Rate
        } else if netIncome <= TaxConstants.tier2Ceiling {
            rawTax = TaxConstants.tier1Ceiling * TaxConstants.tier1Rate
                + (netIncome - TaxConstants.tier1Ceiling) * TaxConstants.tier2Rate
        } else {
            rawTax = TaxConstants.tier1Ceiling * TaxConstants.tier1Rate
                + (TaxConstants.tier2Ceiling - TaxConstants.tier1Ceiling) * TaxConstants.tier2Rate
                + (netIncome - TaxConstants.tier2Ceiling) * TaxConstants.tier3Rate
        }

        let estimatedTax   = max(Decimal(0), rawTax - TaxConstants.persónuafsláttur)
        let pension        = netIncome * TaxConstants.selfEmployedPensionRate
        let tryggingagjald = grossRevenueISK * TaxConstants.tryggingagjaldRate
        let total          = estimatedTax + pension + tryggingagjald

        var pct = Decimal(0)
        if grossRevenueISK > 0 {
            var raw = (total / grossRevenueISK) * 100
            NSDecimalRound(&pct, &raw, 0, .plain)
        }

        return ContractorCalculationResult(
            grossRevenueISK:       grossRevenueISK,
            totalExpensesISK:      totalExpensesISK,
            netIncomeISK:          netIncome,
            estimatedTaxISK:       estimatedTax,
            pensionObligationISK:  pension,
            tryggingagjaldISK:     tryggingagjald,
            totalRetentionISK:     total,
            retentionPercent:      pct
        )
    }
}
