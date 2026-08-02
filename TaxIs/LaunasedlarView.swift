//
//  LaunasedlarView.swift
//  TaxÍs
//
//  Launaseðlar tab (shown to launþegi and blandað users).
//  Replaces the old "Skanna" tab. All payslip data entry happens
//  here via "+ Bæta við" which offers scan or manual entry.
//

import SwiftUI

struct LaunasedlarView: View {
    @EnvironmentObject private var salariedStore: SalariedJobStore

    @State private var showingAddOptions = false
    @State private var showingAddJob = false
    @State private var showingCapture = false

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    addButton
                    contentSection
                }
                .padding(18)
                .padding(.top, 40)
            }
        }
        .confirmationDialog("Bæta við launaseðli", isPresented: $showingAddOptions, titleVisibility: .visible) {
            Button("Skanna launaseðil") { showingCapture = true }
            Button("Slá inn handvirkt") { showingAddJob = true }
            Button("Hætta við", role: .cancel) {}
        }
        .sheet(isPresented: $showingAddJob) {
            AddPayslipSheet(store: salariedStore)
        }
        .sheet(isPresented: $showingCapture) {
            CaptureView()
        }
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Launaseðlar")
                .font(.title2.bold())
                .foregroundStyle(TaxIsTheme.navy)
            Text(monthLabel)
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    private var addButton: some View {
        Button { showingAddOptions = true } label: {
            Label("Bæta við", systemImage: "plus")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaxIsTheme.onMint)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(TaxIsTheme.mint)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var contentSection: some View {
        if salariedStore.currentMonthEntries.isEmpty {
            emptyPrompt
        } else {
            ForEach(salariedStore.currentMonthEntries) { entry in
                payslipRow(entry)
            }
            if let result = salariedStore.currentMonthCalculation {
                resultCard(result)
                if result.discrepancyISK > 0   { discrepancyCard(result) }
                if result.creditOveruseISK > 0 { creditOveruseAlert(result) }
            }
        }
    }

    private var emptyPrompt: some View {
        Button { showingAddOptions = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.title3)
                    .foregroundStyle(TaxIsTheme.mint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Engar launagreiðslur skráðar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.text)
                    Text("Bættu við til að fá skattaútreikning þennan mánuð")
                        .font(.footnote)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func payslipRow(_ entry: SalariedJobEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.employerName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                Text("Brúttó \(formatISK(entry.grossSalaryISK))")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text("Skattur \(formatISK(entry.taxWithheldISK))")
                .font(.caption.weight(.medium))
                .foregroundStyle(TaxIsTheme.muted)
            Button { salariedStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain)
            .padding(.leading, 6)
        }
        .padding(12)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func resultCard(_ r: SalariedCalculationResult) -> some View {
        VStack(spacing: 0) {
            resultRow("Heildarbr\u{FA}tt\u{F3}", value: formatISK(r.combinedGrossISK))
            Divider().background(TaxIsTheme.border)
            resultRow("Skattstofn", value: formatISK(r.taxableBaseISK))
            Divider().background(TaxIsTheme.border)
            resultRow("\u{C1}tlað skattur", value: formatISK(r.expectedTaxISK))
            Divider().background(TaxIsTheme.border)
            resultRow("Greiddur skattur", value: formatISK(r.actualTaxPaidISK))
            if r.isInTier2 {
                Divider().background(TaxIsTheme.border)
                resultRow(
                    r.isInTier3 ? "\u{ED} þrepi 2+3" : "\u{ED} þrepi 2",
                    value: formatISK(r.tier2OverflowISK),
                    accent: TaxIsTheme.amber
                )
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func resultRow(_ label: String, value: String, accent: Color = TaxIsTheme.text) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func discrepancyCard(_ r: SalariedCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(TaxIsTheme.amber)
                Text("Vangreiddur skattur þennan m\u{E1}nuð")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.amber)
            }
            Text("TaxÍs reiknar út að þú sért að vangreiða um \(formatISK(r.discrepancyISK)) þennan mánuð. Þetta er algeng staða þegar laun ná yfir skattþrep 1.")
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.amber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.amberBorder, lineWidth: 1))
    }

    private func creditOveruseAlert(_ r: SalariedCalculationResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill").foregroundStyle(TaxIsTheme.amber)
                Text("Tvöfalt skattkort")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.amber)
            }
            Text("Persónuafsláttur yfir hámarkið \(formatISK(TaxConstants.persónuafsláttur)) á mánuð. Ef tveir vinnuveitendur nýta hann í fullu máli safnast skuld.")
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.amber.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.amberBorder, lineWidth: 1))
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "is_IS")
        return f.string(from: Date()).capitalized
    }
}

// MARK: - Add payslip sheet

private struct AddPayslipSheet: View {
    @ObservedObject var store: SalariedJobStore
    @Environment(\.dismiss) private var dismiss

    @State private var employerName = ""
    @State private var gross = ""
    @State private var taxWithheld = ""
    @State private var pension = ""
    @State private var credit = "\(Int(truncating: TaxConstants.persónuafsláttur as NSDecimalNumber))"

    private var canSave: Bool {
        !employerName.trimmingCharacters(in: .whitespaces).isEmpty
        && parsed(gross) != nil && parsed(taxWithheld) != nil
        && parsed(pension) != nil && parsed(credit) != nil
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Bæta við launaseðli")
                        .font(.headline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Button("Hætta við") { dismiss() }
                        .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                }
                .padding(20)

                ScrollView {
                    VStack(spacing: 12) {
                        field("Launagreiðandi", placeholder: "t.d. Mosfellsbær", text: $employerName, keyboard: .default)
                        field("Brúttólaun (kr.)", placeholder: "t.d. 479645", text: $gross)
                        field("Greiddur skattur (kr.)", placeholder: "t.d. 72520", text: $taxWithheld)
                        field("Lífeyrissjóður starfsm. (kr.)", placeholder: "t.d. 19144", text: $pension)
                        field("Persónuafsláttur notaður (kr.)", placeholder: "72492", text: $credit)

                        Text("Persónuafsláttur er \(formatISK(TaxConstants.persónuafsláttur)) á mánuð. Ef aðeins einn vinnuveitandi, skildu eftir sjálfgefna tölu.")
                            .font(.caption).foregroundStyle(TaxIsTheme.muted).padding(.top, 4)
                    }
                    .padding(.horizontal, 20).padding(.bottom, 32)
                }

                Button { save() } label: {
                    Text("Vista")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canSave ? TaxIsTheme.mint : TaxIsTheme.muted)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(!canSave)
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func field(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .numberPad) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.body).foregroundStyle(TaxIsTheme.text)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
        }
    }

    private func parsed(_ s: String) -> Decimal? {
        guard let v = Decimal(string: s), v >= 0 else { return nil }
        return v
    }

    private func save() {
        guard canSave,
              let g  = parsed(gross),
              let tw = parsed(taxWithheld),
              let p  = parsed(pension),
              let cr = parsed(credit) else { return }
        store.add(SalariedJobEntry(
            employerName: employerName.trimmingCharacters(in: .whitespaces),
            grossSalaryISK: g, taxWithheldISK: tw, pensionDeductedISK: p, taxCreditUsedISK: cr
        ))
        dismiss()
    }
}

#Preview {
    LaunasedlarView()
        .environmentObject(SalariedJobStore())
}
