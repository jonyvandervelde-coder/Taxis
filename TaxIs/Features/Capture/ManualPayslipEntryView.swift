//
//  ManualPayslipEntryView.swift
//  TaxÍs
//
//  Manual payslip entry form — presented as a sheet from CaptureView when
//  the user taps "Slá inn handvirkt" or when OCR fails. The completed
//  ExtractedTransaction is handed back via onComplete so CaptureView can
//  push it through the same TransactionConfirmationView as scanned docs.
//
//  Net pay is auto-calculated from bruttólaun – staðgreiðsla – lífeyrissjóður
//  but the user may override it.
//

import SwiftUI

struct ManualPayslipEntryView: View {
    let onComplete: (ExtractedTransaction) -> Void

    @Environment(\.dismiss) private var dismiss

    // Form state
    @State private var launagreidandi  = ""
    @State private var greidslodagur   = Date()
    @State private var bruttolaun      = ""
    @State private var stadgreidslur   = ""
    @State private var lifeyrissjodur  = ""
    @State private var nettolaun       = ""   // auto-filled or overridden
    @State private var netOverridden   = false

    // Derived net
    private var calculatedNet: Decimal? {
        guard let gross = decimal(bruttolaun) else { return nil }
        let tax     = decimal(stadgreidslur)    ?? Decimal(0)
        let pension = decimal(lifeyrissjodur)   ?? Decimal(0)
        return max(gross - tax - pension, Decimal(0))
    }

    // Validation
    private var canSave: Bool {
        decimal(bruttolaun) != nil && decimal(bruttolaun)! > 0
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TaxIsTheme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        sectionCard {
                            formRow("Launagreiðandi", placeholder: "Nafn fyrirtækis") {
                                TextField("", text: $launagreidandi)
                            }
                            Divider().background(TaxIsTheme.border)
                            formRow("Greiðsludagur", placeholder: "") {
                                DatePicker("", selection: $greidslodagur, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                            }
                        }

                        sectionLabel("Greiðsluupplýsingar")

                        sectionCard {
                            formRow("Laun alls (brúttó)", placeholder: "0") {
                                iskField($bruttolaun)
                                    .onChange(of: bruttolaun) { _, _ in
                                        if !netOverridden { updateNet() }
                                    }
                            }
                            Divider().background(TaxIsTheme.border)
                            formRow("Staðgreiðsla (skattur)", placeholder: "0") {
                                iskField($stadgreidslur)
                                    .onChange(of: stadgreidslur) { _, _ in
                                        if !netOverridden { updateNet() }
                                    }
                            }
                            Divider().background(TaxIsTheme.border)
                            formRow("Lífeyrissjóður", placeholder: "0") {
                                iskField($lifeyrissjodur)
                                    .onChange(of: lifeyrissjodur) { _, _ in
                                        if !netOverridden { updateNet() }
                                    }
                            }
                        }

                        sectionCard {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Útborgað (nettó)")
                                    .font(.subheadline)
                                    .foregroundStyle(TaxIsTheme.text)
                                HStack {
                                    iskField($nettolaun)
                                        .onChange(of: nettolaun) { _, _ in
                                            netOverridden = true
                                        }
                                    if netOverridden {
                                        Button {
                                            netOverridden = false
                                            updateNet()
                                        } label: {
                                            Image(systemName: "arrow.counterclockwise")
                                                .font(.footnote)
                                                .foregroundStyle(TaxIsTheme.muted)
                                        }
                                    }
                                }
                                if !netOverridden, let net = calculatedNet {
                                    Text("Reiknað: \(NSDecimalNumber(decimal: net).intValue) kr.")
                                        .font(.caption)
                                        .foregroundStyle(TaxIsTheme.muted)
                                }
                            }
                            .padding(.horizontal, 15).padding(.vertical, 13)
                        }

                        Button {
                            save()
                        } label: {
                            Text("Áfram til staðfestingar")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canSave ? TaxIsTheme.mint : TaxIsTheme.mint.opacity(0.4))
                                .foregroundStyle(TaxIsTheme.onMint)
                                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                        }
                        .disabled(!canSave)
                    }
                    .padding(18)
                }
            }
            .navigationTitle("Slá inn handvirkt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hætta við") { dismiss() }
                }
            }
        }
    }

    // MARK: - Sub-views

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TaxIsTheme.muted)
            .padding(.horizontal, 2)
    }

    private func sectionCard<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1)
        )
    }

    private func formRow<Content: View>(
        _ label: String,
        placeholder: String,
        @ViewBuilder field: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.text)
            Spacer()
            field()
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
    }

    private func iskField(_ binding: Binding<String>) -> some View {
        HStack(spacing: 4) {
            TextField("0", text: binding)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaxIsTheme.text)
                .frame(maxWidth: 140)
            Text("kr.")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    // MARK: - Logic

    private func updateNet() {
        guard let net = calculatedNet else { return }
        nettolaun = "\(NSDecimalNumber(decimal: net).intValue)"
    }

    private func decimal(_ s: String) -> Decimal? {
        let clean = s.replacingOccurrences(of: ".", with: "")
                     .replacingOccurrences(of: ",", with: ".")
        guard let d = Decimal(string: clean), d >= 0 else { return nil }
        return d
    }

    private func save() {
        let gross  = decimal(bruttolaun)   ?? Decimal(0)
        let tax    = decimal(stadgreidslur) ?? Decimal(0)
        let net: Decimal
        if netOverridden, let n = decimal(nettolaun), n > 0 {
            net = n
        } else {
            net = calculatedNet ?? gross
        }

        let transaction = ExtractedTransaction(
            vendorName: launagreidandi.trimmingCharacters(in: .whitespaces).isEmpty
                ? "Launagreiðandi"
                : launagreidandi.trimmingCharacters(in: .whitespaces),
            vendorKennitala: nil,           // SECURITY: always nil for payslips
            currency: "ISK",
            totalAmountISK: net,
            netAmountISK: net,
            vskAmountISK: Decimal(0),
            vskCategory: .exempt0,
            vskRate: Decimal(0),
            lineItems: nil,
            transactionDate: greidslodagur,
            aiConfidence: 1.0,              // manually entered = full confidence
            sourceDocumentType: .payslip,
            notes: "Handvirkt skráð",
            grossPayISK: gross > 0 ? gross : nil,
            taxWithheldISK: tax > 0 ? tax : nil
        )

        dismiss()
        // Small delay to let the sheet dismiss before navigation fires
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onComplete(transaction)
        }
    }
}

#Preview {
    ManualPayslipEntryView { _ in }
}
