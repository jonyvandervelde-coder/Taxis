//
//  TransactionConfirmationView.swift
//  TaxÍs
//
//  Shows the AI-extracted transaction and requires an explicit user
//  confirmation before it's persisted — nothing is "official" until then,
//  per taxis_schema.sql's extraction_status workflow.
//

import SwiftUI

struct TransactionConfirmationView: View {
    let transaction: ExtractedTransaction
    let onSaved: () -> Void

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var needsReview: Bool {
        ReceiptExtractionService.shared.requiresManualReview(transaction)
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if needsReview {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Low confidence — double-check before saving")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(TaxIsTheme.amber)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TaxIsTheme.amberTint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                .strokeBorder(TaxIsTheme.amberBorder, lineWidth: 1)
                        )
                    }

                    card {
                        row(label: "Vendor", value: transaction.vendorName)
                        if let kennitala = transaction.vendorKennitala {
                            row(label: "Kennitala", value: kennitala)
                        }
                        row(label: "Date", value: ExtractedTransaction.dateOnlyFormatter.string(from: transaction.transactionDate))
                    }

                    card {
                        row(label: "Total", value: amountString(transaction.totalAmountISK))
                        row(label: "Net", value: amountString(transaction.netAmountISK))
                        row(label: "VSK", value: amountString(transaction.vskAmountISK))
                        row(label: "VSK category", value: transaction.vskCategory.displayNameEnglish)
                    }

                    if let notes = transaction.notes, !notes.isEmpty {
                        card {
                            Text(notes)
                                .font(.subheadline)
                                .foregroundStyle(TaxIsTheme.body)
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.subheadline)
                            .foregroundStyle(TaxIsTheme.redText)
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        Text(isSaving ? "Saving…" : "Confirm & save")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TaxIsTheme.mint)
                            .foregroundStyle(TaxIsTheme.onMint)
                            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                    }
                    .disabled(isSaving)
                }
                .padding(16)
            }
        }
        .navigationTitle("Confirm")
    }

    @ViewBuilder
    private func card(@ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1)
        )
    }

    private func row(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(TaxIsTheme.text)
        }
    }

    private func amountString(_ value: Decimal) -> String {
        "\(value) kr."
    }

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let status: ExtractionStatus = needsReview ? .pendingReview : .confirmed
            _ = try await SupabaseTransactionRepository.shared.save(
                transaction,
                originalTextHash: nil,
                aiModel: "claude-sonnet-5",
                aiRawResponse: ReceiptExtractionService.shared.lastRawResponseJSON ?? [:],
                status: status
            )
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
