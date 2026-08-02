//
//  UtgjoldView.swift
//  TaxÍs
//
//  Two segments: "Útgjöld" (expenses) and "Akstursbók" (driving log).
//

import SwiftUI

private let suggestedCategories = [
    "Bensín / Akstur",
    "Sími & Net",
    "Tölvubúnaður",
    "Aðkeypt þjónusta",
    "Önnur gjöld",
]

private let purposeSuggestions = [
    "Fundi hjá viðskiptavini",
    "Þjálfun / námskeið",
    "Birgðakaup",
    "Þjónustuvísit",
    "Önnur ferð í vinnuskyni",
]

struct UtgjoldView: View {
    @EnvironmentObject var expenseStore: VerktakiExpenseStore
    @EnvironmentObject var aksturStore: AkstursbokStore

    @State private var segment: Segment = .utgjold
    @State private var showingAddOptions = false
    @State private var showingCapture    = false
    @State private var showingManualEntry = false
    @State private var showingAddDrive   = false

    enum Segment: String, CaseIterable {
        case utgjold  = "Útgjöld"
        case akstur   = "Akstursbók"
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    pageHeader
                    segmentPicker
                    if segment == .utgjold {
                        expensesContent
                    } else {
                        aksturContent
                    }
                }
                .padding(18)
                .padding(.top, 40)
                .padding(.bottom, 20)
            }
        }
        // Expense dialogs
        .confirmationDialog("Bæta við útgjöldum", isPresented: $showingAddOptions, titleVisibility: .visible) {
            Button("Skanna kvittun") { showingCapture = true }
            Button("Slá inn handvirkt") { showingManualEntry = true }
            Button("Hætta við", role: .cancel) {}
        }
        .sheet(isPresented: $showingCapture)     { CaptureView() }
        .sheet(isPresented: $showingManualEntry)  { AddExpenseSheet(store: expenseStore) }
        .sheet(isPresented: $showingAddDrive)     { AddDriveSheet(store: aksturStore) }
    }

    // MARK: - Shared header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Útgjöld")
                .font(.title2.bold())
                .foregroundStyle(TaxIsTheme.navy)
            Text(segment == .utgjold
                 ? "Frádráttarbær útgjöld þennan mánuð"
                 : "Akstursbók og ökutækjastyrkur")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(Segment.allCases, id: \.self) { s in
                Button { segment = s } label: {
                    Text(s.rawValue)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(segment == s ? TaxIsTheme.mint : Color.clear)
                        .foregroundStyle(segment == s ? TaxIsTheme.onMint : TaxIsTheme.muted)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control - 1))
                }
                .buttonStyle(.plain)
                .padding(2)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    // MARK: - Expenses content

    private var expensesContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { showingAddOptions = true } label: {
                Label("Bæta við útgjöldum", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.onMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(TaxIsTheme.mint)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            }
            .buttonStyle(.plain)

            totalChip
            quickRepeat
            expenseList
        }
    }

    private var totalChip: some View {
        HStack {
            Text("Frádráttur þennan mánuð")
                .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
            Spacer()
            Text(formatISK(expenseStore.totalThisMonth))
                .font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.text)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    @ViewBuilder
    private var quickRepeat: some View {
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
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(TaxIsTheme.mintTint)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(TaxIsTheme.mint.opacity(0.4), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var expenseList: some View {
        if expenseStore.entriesThisMonth.isEmpty {
            Text("Engin útgjöld skráð þennan mánuð.")
                .font(.footnote).foregroundStyle(TaxIsTheme.muted)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(expenseStore.entriesThisMonth.enumerated()), id: \.element.id) { idx, entry in
                    if idx > 0 { Divider().background(TaxIsTheme.border) }
                    expenseRow(entry)
                }
            }
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
    }

    private func expenseRow(_ entry: VerktakiExpenseEntry) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.category)
                    .font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.text)
                Text(entry.date, format: .dateTime.day().month())
                    .font(.caption).foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text(formatISK(entry.amountISK))
                .font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.text)
            Button { expenseStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain).padding(.leading, 6)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Akstursbók content

    private var aksturContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Button { showingAddDrive = true } label: {
                Label("Skrá akstur", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.onMint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(TaxIsTheme.mint)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            }
            .buttonStyle(.plain)

            aksturSummary
            driveList
        }
    }

    private var aksturSummary: some View {
        VStack(spacing: 0) {
            summaryRow(
                label: "Samtals km þetta ár",
                value: String(format: "%.0f km", aksturStore.totalKm),
                showDivider: true
            )
            summaryRow(
                label: "Áætlaður frádráttur",
                value: String(format: "%.0f kr.", aksturStore.estimatedDeductionISK),
                showDivider: true
            )
            HStack {
                Text("66 kr/km (1–5.000 km) · 40 kr/km yfir það")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.mint.opacity(0.35), lineWidth: 1))
    }

    private func summaryRow(label: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(value).font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.text)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            if showDivider { Divider().background(TaxIsTheme.border) }
        }
    }

    @ViewBuilder
    private var driveList: some View {
        if aksturStore.entries.isEmpty {
            Text("Enginn akstur skráður. Ýttu á \"Skrá akstur\" til að bæta við.")
                .font(.footnote).foregroundStyle(TaxIsTheme.muted)
                .padding(14).frame(maxWidth: .infinity, alignment: .leading)
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        } else {
            VStack(spacing: 0) {
                ForEach(Array(aksturStore.entries.reversed().enumerated()), id: \.element.id) { idx, entry in
                    if idx > 0 { Divider().background(TaxIsTheme.border) }
                    driveRow(entry)
                }
            }
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
    }

    private func driveRow(_ entry: AksturEntry) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.from.isEmpty ? "—" : entry.from)
                    if !entry.to.isEmpty {
                        Image(systemName: "arrow.right").font(.caption2)
                        Text(entry.to)
                    }
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.text)

                if !entry.purpose.isEmpty {
                    Text(entry.purpose).font(.caption).foregroundStyle(TaxIsTheme.muted)
                }
                Text(entry.date, format: .dateTime.day().month().year())
                    .font(.caption2).foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f km", entry.km))
                    .font(.subheadline.weight(.semibold)).foregroundStyle(TaxIsTheme.text)
            }
            Button { aksturStore.remove(entry) } label: {
                Image(systemName: "xmark.circle.fill").foregroundStyle(TaxIsTheme.muted)
            }
            .buttonStyle(.plain).padding(.leading, 6)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }
}

// MARK: - Add expense sheet

private struct AddExpenseSheet: View {
    @ObservedObject var store: VerktakiExpenseStore
    @Environment(\.dismiss) private var dismiss
    @State private var category = ""
    @State private var amount   = ""

    private var parsed: Decimal? {
        guard let v = Decimal(string: amount), v > 0 else { return nil }
        return v
    }
    private var canSave: Bool {
        !category.trimmingCharacters(in: .whitespaces).isEmpty && parsed != nil
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Bæta við útgjöldum")
                        .font(.headline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Button("Hætta við") { dismiss() }
                        .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                }
                .padding(20)

                VStack(spacing: 12) {
                    fieldView(label: "Flokkur", placeholder: "t.d. Bensín / Akstur", text: $category)
                    if category.trimmingCharacters(in: .whitespaces).isEmpty {
                        suggestionsRow(suggestedCategories) { category = $0 }
                    }
                    fieldView(label: "Upphæð (kr.)", placeholder: "t.d. 15000", text: $amount, keyboard: .numberPad)
                }
                .padding(.horizontal, 20)

                Spacer()

                Button {
                    if let v = parsed {
                        store.add(category: category.trimmingCharacters(in: .whitespaces), amountISK: v)
                        dismiss()
                    }
                } label: {
                    Text("Vista").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(canSave ? TaxIsTheme.mint : TaxIsTheme.muted)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(!canSave)
                .padding(20)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Add drive sheet

private struct AddDriveSheet: View {
    @ObservedObject var store: AkstursbokStore
    @Environment(\.dismiss) private var dismiss

    @State private var from    = ""
    @State private var to      = ""
    @State private var km      = ""
    @State private var purpose = ""
    @State private var date    = Date()

    private var canSave: Bool {
        Double(km) ?? 0 > 0
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Skrá akstur")
                        .font(.headline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Button("Hætta við") { dismiss() }
                        .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                }
                .padding(20)

                ScrollView {
                    VStack(spacing: 12) {
                        DatePicker("Dagsetning", selection: $date, displayedComponents: .date)
                            .font(.subheadline).foregroundStyle(TaxIsTheme.text)
                            .tint(TaxIsTheme.mint)

                        fieldView(label: "Frá", placeholder: "t.d. Reykjavík", text: $from)
                        fieldView(label: "Til", placeholder: "t.d. Keflavíkurflugvöllur", text: $to)
                        fieldView(label: "Kílómetrar", placeholder: "t.d. 48", text: $km, keyboard: .decimalPad)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erindi").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
                            TextField("t.d. Fundur hjá viðskiptavini", text: $purpose)
                                .font(.body).foregroundStyle(TaxIsTheme.text)
                                .padding(10)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
                        }

                        if purpose.trimmingCharacters(in: .whitespaces).isEmpty {
                            suggestionsRow(purposeSuggestions) { purpose = $0 }
                        }
                    }
                    .padding(.horizontal, 20)
                }

                Button {
                    if let kmVal = Double(km), kmVal > 0 {
                        store.add(AksturEntry(date: date, from: from, to: to, km: kmVal, purpose: purpose))
                        dismiss()
                    }
                } label: {
                    Text("Vista").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(canSave ? TaxIsTheme.mint : TaxIsTheme.muted)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(!canSave)
                .padding(20)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Shared helpers

private func fieldView(label: String, placeholder: String, text: Binding<String>,
                       keyboard: UIKeyboardType = .default) -> some View {
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

private func suggestionsRow(_ items: [String], onSelect: @escaping (String) -> Void) -> some View {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { s in
                Button(s) { onSelect(s) }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TaxIsTheme.muted)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(TaxIsTheme.bg)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
            }
        }
    }
}

#Preview {
    UtgjoldView()
        .environmentObject(VerktakiExpenseStore())
        .environmentObject(AkstursbokStore())
}
