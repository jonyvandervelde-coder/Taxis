//
//  TransactionsListView.swift
//  TaxÍs
//

import SwiftUI

struct TransactionsListView: View {
    @State private var transactions: [TransactionRecord] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()

            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.redText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            } else if transactions.isEmpty && !isLoading {
                Text("Engar færslur enn")
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
            } else {
                List {
                    ForEach(transactions) { record in
                        TransactionRow(record: record)
                            .listRowBackground(TaxIsTheme.card)
                    }
                    .onDelete(perform: deleteItems)
                }
                .scrollContentBackground(.hidden)
                .refreshable { await load() }
            }
        }
        .navigationTitle("Launaseðlar")
        .task { await load() }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            transactions = try await SupabaseTransactionRepository.shared.fetchTransactions()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        let toDelete = offsets.map { transactions[$0] }
        transactions.remove(atOffsets: offsets)
        Task {
            for record in toDelete {
                guard let id = record.id else { continue }
                try? await SupabaseTransactionRepository.shared.delete(id: id)
            }
        }
    }
}

private struct TransactionRow: View {
    let record: TransactionRecord

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(record.vendorName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                Text(ExtractedTransaction.dateOnlyFormatter.string(from: record.transactionDate))
                    .font(.footnote)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(verbatim: "\(NSDecimalNumber(decimal: record.totalAmountISK).intValue) kr.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TaxIsTheme.text)
                statusBadge
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch record.extractionStatus {
        case .confirmed:
            badge(text: "Staðfest",  fg: TaxIsTheme.mintText, bg: TaxIsTheme.mintTint)
        case .pendingReview:
            badge(text: "Yfirfara",  fg: TaxIsTheme.amber,    bg: TaxIsTheme.amberTint)
        case .rejected:
            badge(text: "Hafnað",    fg: TaxIsTheme.redText,  bg: TaxIsTheme.red.opacity(0.1))
        }
    }

    private func badge(text: String, fg: Color, bg: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.pill))
    }
}

#Preview {
    TransactionsListView()
}
