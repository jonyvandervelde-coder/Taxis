//
//  DeductionsView.swift
//  TaxÍs
//
//  "Frádráttur" tab — shown to verktaki users (pure contractor and blandað).
//  Sections in order:
//    1. Verktakatekjur — revenue entry + this-month list + month total
//    2. VSK threshold gauge — rolling 12-month bar, warning state
//    3. Skatturinn Shield — contractor retention breakdown
//    4. Útgjöld — deductible expense log (VerktakiExpenseStore)
//    5. Reference cards — static Skatturinn box-number reference
//

import SwiftUI

// MARK: - Static reference data

private struct DeductionInfo: Identifiable {
    let id = UUID()
    let name: String
    let box: String
    let note: String
    let cap: String
}

private let deductions: [DeductionInfo] = [
    DeductionInfo(
        name: "Líkamsræktarstyrkur",
        box: "157",
        note: "Skattlagt sem laun fyrst, síðan frádráttarbært. Almenn regla frá Skatturinn.",
        cap: "81.000 kr./ár"
    ),
    DeductionInfo(
        name: "Samgöngugreiðslur",
        box: "157",
        note: "Samgöngustyrkur frá vinnuveitanda, skattlagður fyrst.",
        cap: "132.000 kr./ár (11.000/mán.)"
    ),
    DeductionInfo(
        name: "Ökutækjastyrkur",
        box: "32",
        note: "Krefst akstursdagbókar — dagsetning, vegalengd, tilgangur.",
        cap: "Aldrei umfram greiddan styrk"
    ),
    DeductionInfo(
        name: "Gjafir til almannaheillafélaga",
        box: "155",
        note: "Frádráttarbært gegn kvittun frá viðurkenndum félögum.",
        cap: "10.000–350.000 kr./ár"
    ),
]

private let suggestedCategories = [
    "Bensín / Akstur",
    "Sími & Net",
    "Tölvubúnaður",
    "Aðkeypt þjónusta",
    "Önnur gjöld",
]

// MARK: - View

struct DeductionsView: View {
    @EnvironmentObject var expenseStore: VerktakiExpenseStore
    @EnvironmentObject var revenueStore: VerktakiRevenueStore

    @State private var newCategory = ""
    @State private var newAmount = ""
    @State private var newRevenueDescription = ""
    @State private var newRevenueAmount = ""

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pageHeader

                    revenueSection
                    vskGauge
                    skatturinnShieldCard
                    expenseLogSection
                    referenceSection
                }
                .padding(18)
                .padding(.top, 40)
            }
        }
    }

    // MARK: - Page header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Frádráttur")
                .font(.title2.bold())
                .foregroundStyle(TaxIsTheme.navy)
            Text("Skráðu tekjur og útgjöld — TaxÍs reiknar hvað þú þarft að setja til hliðar.")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    // MARK: - Revenue section

    private var revenueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Verktakatekjur þessa mánaðar")
                .font(.headline)
                .foregroundStyle(TaxIsTheme.text)

            // Month total chip
            HStack {
                Text("Samtals þennan mánuð")
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(formatISK(revenueStore.currentMonthTotal))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
            }

            // Add-revenue form
            revenueEntryForm

            // This-month list
            if !revenueStore.currentMonthEntries.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(revenueStore.currentMonthEntries.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 { Rectangle().fill(TaxIsTheme.border).frame(height: 1) }
                        revenueRow(entry)
                    }
                }
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
            }
        }
    }

    private var revenueEntryForm: some View {
        VStack(spacing: 8) {
            TextField("Lýsing (t.d. Verkefni hjá ABC ehf.)", text: $newRevenueDescription)
                .expenseField()
            TextField("Brúttóupphæð (kr.)", text: $newRevenueAmount)
                .keyboardType(.numberPad)
                .expenseField()
            Button { addRevenue() } label: {
                Text("Bæta við tekjum")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canAddRevenue ? TaxIsTheme.mint : TaxIsTheme.muted)
                    .foregroundStyle(TaxIsTheme.onMint)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            }
            .disabled(!canAddRevenue)
        }
        .padding(14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var canAddRevenue: Bool {
        !newRevenueDescription.trimmingCharacters(in: .whitespaces).isEmpty
        && parsedRevenueAmount != nil
    }

    private var parsedRevenueAmount: Decimal? {
        guard let v = Decimal(string: newRevenueAmount), v > 0 else { return nil }
        return v
    }

    private func addRevenue() {
        guard let amount = parsedRevenueAmount else { return }
        let desc = newRevenueDescription.trimmingCharacters(in: .whitespaces)
        guard !desc.isEmpty else { return }
        revenueStore.add(description: desc, grossRevenueISK: amount)
        newRevenueDescription = ""
        newRevenueAmount = ""
    }

    private func revenueRow(_ entry: VerktakiRevenueEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                Text(entry.date, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text(formatISK(entry.grossRevenueISK))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaxIsTheme.text)
            Button { revenueStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - VSK gauge

    private var vskGauge: some View {
        let fraction   = revenueStore.vskThresholdFraction
        let isWarning  = revenueStore.isNearVskThreshold
        let remaining  = revenueStore.vskRemainingISK
        let barColor   = isWarning ? TaxIsTheme.amber : TaxIsTheme.mint

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VSK-þröskuldur (12 mánaðar)")
                    .font(.headline)
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                if isWarning {
                    Label("Nálægt þröskuldi", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.amber)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TaxIsTheme.bg)
                    Capsule().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
                    Capsule()
                        .fill(barColor)
                        .frame(width: max(4, geo.size.width * CGFloat(fraction)))
                        .shadow(color: barColor.opacity(0.5), radius: 5)
                        .animation(.easeInOut, value: fraction)
                }
            }
            .frame(height: 14)

            HStack {
                Text(formatISK(revenueStore.rolling12MonthTotal))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                Text("Eftir: \(formatISK(remaining))")
                    .font(.caption)
                    .foregroundStyle(isWarning ? TaxIsTheme.amber : TaxIsTheme.muted)
                Spacer()
                Text("2.000.000 kr.")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }

            if isWarning {
                Text("Þú ert að nálgast VSK-skráningarþröskuldinn. Fáðu VSK-númer hjá Skatturinn áður en tekjur fara yfir 2.000.000 kr.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(isWarning ? TaxIsTheme.amber.opacity(0.07) : TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(isWarning ? TaxIsTheme.amberBorder : TaxIsTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Skatturinn Shield

    private var skatturinnShieldCard: some View {
        let gross    = revenueStore.currentMonthTotal
        let expenses = expenseStore.totalThisMonth

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.fill")
                    .foregroundStyle(TaxIsTheme.mint)
                Text("Skatturinn Shield")
                    .font(.headline)
                    .foregroundStyle(TaxIsTheme.text)
            }

            if gross <= 0 {
                Text("Skráðu tekjur hér að ofan til að sjá hvað þú þarft að leggja til hliðar.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.muted)
            } else {
                let r = TaxCalculationEngine.calculateContractor(
                    grossRevenueISK: gross,
                    totalExpensesISK: expenses
                )
                shieldRows(r)
            }
        }
        .padding(14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func shieldRows(_ r: ContractorCalculationResult) -> some View {
        VStack(spacing: 0) {
            shieldRow("Skattur (tekjuskattur)", value: formatISK(r.estimatedTaxISK))
            Rectangle().fill(TaxIsTheme.border).frame(height: 1)
            shieldRow("Lífeyrir (12% af nettó)", value: formatISK(r.pensionObligationISK))
            Rectangle().fill(TaxIsTheme.border).frame(height: 1)
            shieldRow("Tryggingagjald (6,35% af brúttó)", value: formatISK(r.tryggingagjaldISK))
            Rectangle().fill(TaxIsTheme.border.opacity(0.8)).frame(height: 2)
            HStack {
                Text("Samtals til hliðar")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatISK(r.totalRetentionISK))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(TaxIsTheme.mint)
                    Text(verbatim: "≈ \(NSDecimalNumber(decimal: r.retentionPercent).intValue)% af tekjum")
                        .font(.caption)
                        .foregroundStyle(TaxIsTheme.muted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(TaxIsTheme.bg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card - 2))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card - 2).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func shieldRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
            Spacer()
            Text(value)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(TaxIsTheme.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Expense log

    private var expenseLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Útgjöld þessa mánaðar")
                .font(.headline)
                .foregroundStyle(TaxIsTheme.text)

            HStack {
                Text("Frádráttur þennan mánuð")
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(formatISK(expenseStore.totalThisMonth))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
            }

            if !expenseStore.recentCategories.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(expenseStore.recentCategories, id: \.category) { item in
                            Button {
                                expenseStore.add(category: item.category, amountISK: item.lastAmount)
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("\(item.category) · \(formatISK(item.lastAmount))")
                                }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TaxIsTheme.mintText)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(TaxIsTheme.mintTint)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(TaxIsTheme.mint.opacity(0.4), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            newExpenseForm

            if !expenseStore.entriesThisMonth.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(expenseStore.entriesThisMonth.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Rectangle().fill(TaxIsTheme.border).frame(height: 1) }
                        expenseRow(entry)
                    }
                }
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
            }
        }
    }

    private var newExpenseForm: some View {
        VStack(spacing: 8) {
            TextField("Flokkur (t.d. Bensín / Akstur)", text: $newCategory)
                .expenseField()

            if newCategory.trimmingCharacters(in: .whitespaces).isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestedCategories, id: \.self) { suggestion in
                            Button(suggestion) { newCategory = suggestion }
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TaxIsTheme.muted)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(TaxIsTheme.bg)
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
                        }
                    }
                }
            }

            TextField("Upphæð (kr.)", text: $newAmount)
                .keyboardType(.numberPad)
                .expenseField()

            Button { addExpense() } label: {
                Text("Bæta við útgjöldum")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canAddExpense ? TaxIsTheme.mint : TaxIsTheme.muted)
                    .foregroundStyle(TaxIsTheme.onMint)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            }
            .disabled(!canAddExpense)
        }
        .padding(14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var canAddExpense: Bool {
        !newCategory.trimmingCharacters(in: .whitespaces).isEmpty && parsedExpenseAmount != nil
    }

    /// `Decimal(string:)` is lenient — "ef3500" parses as 0 not nil — so > 0 is required.
    private var parsedExpenseAmount: Decimal? {
        guard let amount = Decimal(string: newAmount), amount > 0 else { return nil }
        return amount
    }

    private func addExpense() {
        guard let amount = parsedExpenseAmount else { return }
        let category = newCategory.trimmingCharacters(in: .whitespaces)
        guard !category.isEmpty else { return }
        expenseStore.add(category: category, amountISK: amount)
        newCategory = ""
        newAmount = ""
    }

    private func expenseRow(_ entry: VerktakiExpenseEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                Text(entry.date, format: .dateTime.day().month())
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text(formatISK(entry.amountISK))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaxIsTheme.text)
            Button { expenseStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Reference cards

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Almennar frádráttarreglur")
                .font(.headline)
                .foregroundStyle(TaxIsTheme.text)

            Text("Skatturinn-uppflettitafla — ekki einstaklingsráðgjöf.")
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
                .padding(13)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                        .strokeBorder(TaxIsTheme.borderStrong.opacity(0.35), lineWidth: 1)
                )

            ForEach(deductions) { deduction in
                deductionCard(deduction)
            }
        }
    }

    private func deductionCard(_ deduction: DeductionInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(deduction.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                Text("reitur \(deduction.box)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TaxIsTheme.mint)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(TaxIsTheme.mintTint)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(TaxIsTheme.mint.opacity(0.4), lineWidth: 1))
            }
            Text(deduction.note)
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
            Text("Þak: \(deduction.cap)")
                .font(.caption)
                .foregroundStyle(TaxIsTheme.muted)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }
}

// MARK: - TextField modifier

private extension View {
    func expenseField() -> some View {
        self
            .font(.body)
            .foregroundStyle(TaxIsTheme.text)
            .padding(10)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
            )
    }
}

#Preview {
    DeductionsView()
        .environmentObject(VerktakiExpenseStore())
        .environmentObject(VerktakiRevenueStore())
}
