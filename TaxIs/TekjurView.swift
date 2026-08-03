//
//  TekjurView.swift
//  TaxÍs
//
//  Tekjur tab for verktaki and blandað users.
//  Shows: revenue entry (with scan/manual options), VSK gauge, Skatturinn Shield.
//

import SwiftUI

private let suggestedCategories = ["Þjónustugjald", "Verklaun", "Ráðgjöf", "Sala á vöru", "Annað"]

struct TekjurView: View {
    @EnvironmentObject var revenueStore: VerktakiRevenueStore
    @EnvironmentObject var expenseStore: VerktakiExpenseStore

    @State private var showingAddOptions = false
    @State private var showingCapture = false
    @State private var showingManualEntry = false
    @State private var newDescription = ""
    @State private var newAmount = ""

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pageHeader
                    addButton
                    revenueList
                    vskGauge
                    skatturinnShieldCard
                }
                .padding(18)
                .padding(.top, 40)
            }
        }
        .confirmationDialog("Bæta við tekjum", isPresented: $showingAddOptions, titleVisibility: .visible) {
            Button("Skanna reikning") { showingCapture = true }
            Button("Slá inn handvirkt") { showingManualEntry = true }
            Button("Hætta við", role: .cancel) {}
        }
        .sheet(isPresented: $showingCapture) { CaptureView() }
        .sheet(isPresented: $showingManualEntry) { AddRevenueSheet(store: revenueStore) }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tekjur")
                .font(.title2.bold())
                .foregroundStyle(TaxIsTheme.navy)
            Text("Tekjur þessa mánaðar og VSK-þröskuldur (12 mán.)")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    private var addButton: some View {
        Button { showingAddOptions = true } label: {
            Label("Bæta við tekjum", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaxIsTheme.onMint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(TaxIsTheme.mint)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        }
        .buttonStyle(.plain)
    }

    private var revenueList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Verktakatekjur þessa mánaðar")
                    .font(.headline)
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                Text(formatISK(revenueStore.currentMonthTotal))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
            }

            if revenueStore.currentMonthEntries.isEmpty {
                Text("Engar tekjur skráðar þennan mánuð.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.muted)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(TaxIsTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                        .strokeBorder(TaxIsTheme.border, lineWidth: 1))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(revenueStore.currentMonthEntries.enumerated()), id: \.element.id) { idx, entry in
                        if idx > 0 { Divider().background(TaxIsTheme.border) }
                        revenueRow(entry)
                    }
                }
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(TaxIsTheme.border, lineWidth: 1))
            }
        }
    }

    private func revenueRow(_ entry: VerktakiRevenueEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.description)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                Text(entry.date, format: .dateTime.day().month())
                    .font(.caption).foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text(formatISK(entry.grossRevenueISK))
                .font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.text)
            Button { revenueStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain).padding(.leading, 6)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - VSK gauge

    private var vskGauge: some View {
        let fraction  = revenueStore.vskThresholdFraction
        let isOver    = revenueStore.isOverVskThreshold
        let isWarning = revenueStore.isNearVskThreshold
        let barColor: Color = isOver ? TaxIsTheme.redText : (isWarning ? TaxIsTheme.amber : TaxIsTheme.mint)

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("VSK-þröskuldur (12 mánaðar)")
                    .font(.headline).foregroundStyle(TaxIsTheme.text)
                Spacer()
                if isOver {
                    Label("Farið yfir þröskuldinn!", systemImage: "exclamationmark.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.redText)
                } else if isWarning {
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
                    .font(.caption.weight(.semibold)).foregroundStyle(TaxIsTheme.text)
                Spacer()
                if isOver {
                    Text("Yfir þröskuldi um: \(formatISK(revenueStore.vskOverageISK))")
                        .font(.caption).foregroundStyle(TaxIsTheme.redText)
                } else {
                    Text("Eftir: \(formatISK(revenueStore.vskRemainingISK))")
                        .font(.caption).foregroundStyle(isWarning ? TaxIsTheme.amber : TaxIsTheme.muted)
                }
                Spacer()
                Text("2.000.000 kr.").font(.caption).foregroundStyle(TaxIsTheme.muted)
            }

            if isOver {
                Text("Þú hefur farið yfir VSK-skráningarþröskuldinn. Þú verður að skrá þig sem VSK-skyldur aðili hjá Skatturinn án tafar.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.redText)
                    .fixedSize(horizontal: false, vertical: true)
            } else if isWarning {
                Text("Þú ert að nálgast VSK-skráningarþröskuldinn. Fáðu VSK-númer hjá Skatturinn áður en tekjur fara yfir 2.000.000 kr.")
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.amber)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .background(isOver ? TaxIsTheme.redText.opacity(0.07) : (isWarning ? TaxIsTheme.amber.opacity(0.07) : TaxIsTheme.card))
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(isOver ? TaxIsTheme.redText.opacity(0.3) : (isWarning ? TaxIsTheme.amberBorder : TaxIsTheme.border), lineWidth: 1)
        )
    }

    // MARK: - Skatturinn Shield

    private var skatturinnShieldCard: some View {
        let gross    = revenueStore.currentMonthTotal
        let expenses = expenseStore.totalThisMonth

        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.fill").foregroundStyle(TaxIsTheme.mint)
                Text("Skatturinn Shield")
                    .font(.headline).foregroundStyle(TaxIsTheme.text)
            }

            if gross <= 0 {
                Text("Skráðu tekjur til að sjá hvað þú þarft að leggja til hliðar.")
                    .font(.footnote).foregroundStyle(TaxIsTheme.muted)
            } else {
                let r = TaxCalculationEngine.calculateContractor(
                    grossRevenueISK: gross, totalExpensesISK: expenses
                )
                shieldRows(r)
            }
        }
        .padding(14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func shieldRows(_ r: ContractorCalculationResult) -> some View {
        VStack(spacing: 0) {
            shieldRow("Skattur (tekjuskattur)", value: formatISK(r.estimatedTaxISK))
            Divider().background(TaxIsTheme.border)
            shieldRow("Lífeyrir (12% af nettó)", value: formatISK(r.pensionObligationISK))
            Divider().background(TaxIsTheme.border)
            shieldRow("Tryggingagjald (6,35% af brúttó)", value: formatISK(r.tryggingagjaldISK))
            Rectangle().fill(TaxIsTheme.border.opacity(0.8)).frame(height: 2)
            HStack {
                Text("Samtals til hliðar")
                    .font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.text)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatISK(r.totalRetentionISK))
                        .font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.mint)
                    Text(verbatim: "≈ \(NSDecimalNumber(decimal: r.retentionPercent).intValue)% af tekjum")
                        .font(.caption).foregroundStyle(TaxIsTheme.muted)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
        }
        .background(TaxIsTheme.bg.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card - 2))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card - 2)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func shieldRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).font(.footnote).foregroundStyle(TaxIsTheme.muted)
            Spacer()
            Text(value).font(.footnote.weight(.semibold)).foregroundStyle(TaxIsTheme.text)
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
    }
}

// MARK: - Add revenue sheet

private struct AddRevenueSheet: View {
    @ObservedObject var store: VerktakiRevenueStore
    @Environment(\.dismiss) private var dismiss

    @State private var desc = ""
    @State private var amount = ""

    private var parsed: Decimal? {
        guard let v = Decimal(string: amount), v > 0 else { return nil }
        return v
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Bæta við tekjum")
                        .font(.headline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Button("Hætta við") { dismiss() }
                        .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                }
                .padding(20)

                VStack(spacing: 12) {
                    field("Lýsing", placeholder: "t.d. Verkefni hjá ABC ehf.", text: $desc, keyboard: .default)
                    field("Brúttóupphæð (kr.)", placeholder: "t.d. 300000", text: $amount)
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    if let v = parsed {
                        store.add(description: desc.trimmingCharacters(in: .whitespaces), grossRevenueISK: v)
                        dismiss()
                    }
                } label: {
                    Text("Vista")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background((parsed != nil && !desc.trimmingCharacters(in: .whitespaces).isEmpty) ? TaxIsTheme.mint : TaxIsTheme.muted)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(parsed == nil || desc.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(20)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.body).foregroundStyle(TaxIsTheme.text)
                .padding(10)
                .background(TaxIsTheme.inputBg)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
        }
    }
}

#Preview {
    TekjurView()
        .environmentObject(VerktakiRevenueStore())
        .environmentObject(VerktakiExpenseStore())
}
