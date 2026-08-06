//
//  TransactionConfirmationView.swift
//  TaxÍs
//
//  Shows the AI-extracted (or manually entered) transaction and requires
//  an explicit user confirmation before it's persisted. Nothing is
//  "official" until then, per taxis_schema.sql's extraction_status workflow.
//
//  "Hætta við" in the nav bar discards the transaction without saving.
//

import SwiftUI

struct TransactionConfirmationView: View {
    let transaction: ExtractedTransaction
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var payslipStore: PayslipStore

    @State private var isSaving = false
    @State private var errorMessage: String?

    private var needsReview: Bool {
        ReceiptExtractionService.shared.requiresManualReview(transaction)
    }

    private var isManual: Bool {
        transaction.aiConfidence >= 1.0
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {

                    // Low-confidence warning (not shown for manual entries)
                    if needsReview && !isManual {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Lítil öryggi — vinsamlegast yfirfarðu áður en þú vistar.")
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

                    if isManual {
                        HStack(spacing: 6) {
                            Image(systemName: "square.and.pencil")
                            Text("Handvirkt skráð")
                        }
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(TaxIsTheme.mint)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TaxIsTheme.mintTint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                        .overlay(
                            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                .strokeBorder(TaxIsTheme.mint.opacity(0.35), lineWidth: 1)
                        )
                    }

                    // Vendor / date card
                    card {
                        row(
                            label: transaction.sourceDocumentType == .payslip
                                ? "Launagreiðandi" : "Sala-/þjónustuaðili",
                            value: transaction.vendorName
                        )
                        if let kennitala = transaction.vendorKennitala {
                            row(label: "Kennitala", value: kennitala)
                        }
                        row(
                            label: "Dagsetning",
                            value: ExtractedTransaction.dateOnlyFormatter.string(from: transaction.transactionDate)
                        )
                    }

                    // Financial card
                    card {
                        row(label: "Heildarupphæð", value: amountString(transaction.totalAmountISK))
                        if transaction.sourceDocumentType == .payslip {
                            if let gross = transaction.grossPayISK {
                                row(label: "Bruttólaun", value: amountString(gross))
                            }
                            if let tax = transaction.taxWithheldISK {
                                row(label: "Staðgreiðsla", value: amountString(tax))
                            }
                        } else {
                            row(label: "Nettó", value: amountString(transaction.netAmountISK))
                            row(label: "VSK", value: amountString(transaction.vskAmountISK))
                            row(label: "VSK-flokkur", value: transaction.vskCategory.displayNameIcelandic)
                        }
                    }

                    // Notes card
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

                    // Save button
                    Button {
                        Task { await save() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().tint(TaxIsTheme.onMint)
                            } else {
                                Text("Staðfesta og vista")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(TaxIsTheme.mint)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                    }
                    .disabled(isSaving)
                }
                .padding(16)
            }
        }
        .navigationTitle("Staðfesta")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Hætta við") { dismiss() }
                    .foregroundStyle(TaxIsTheme.muted)
            }
        }
    }

    // MARK: - Sub-views

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
        let n = NSDecimalNumber(decimal: value)
        return "\(n.intValue) kr."
    }

    // MARK: - Save

    private func save() async {
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let status: ExtractionStatus = (needsReview && !isManual) ? .pendingReview : .confirmed
            _ = try await SupabaseTransactionRepository.shared.save(
                transaction,
                originalTextHash: nil,
                aiModel: isManual ? "manual" : "claude-haiku-4-5-20251001",
                aiRawResponse: ReceiptExtractionService.shared.lastRawResponseJSON ?? [:],
                status: status
            )
            // Pre-warm the Heim total so it's ready as soon as the user
            // navigates back, without requiring an extra tab-switch.
            if transaction.sourceDocumentType == .payslip {
                Task { await payslipStore.refresh() }
            }
            onSaved()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

