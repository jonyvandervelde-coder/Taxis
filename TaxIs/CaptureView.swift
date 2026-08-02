//
//  CaptureView.swift
//  TaxÍs
//
//  "Skanna" tab, ported from TaxIs Mockup.dc.html's "Scan" state. Photo or
//  PDF -> text (Vision OCR for photos, PDFKit's text layer for PDFs, which
//  skips OCR entirely and is more reliable for payslip PDFs, which are
//  almost always text-based) -> ReceiptExtractionService. Uses PhotosPicker
//  (out-of-process system picker) rather than a custom camera/library UI,
//  so no NSPhotoLibraryUsageDescription is needed and it's exercisable in
//  the Simulator, which has no camera.
//
//  This is where a user fetches their own payslip or receipt data any
//  time — not gated behind onboarding. The doc-type toggle tells the
//  extraction service which privacy rules apply (payslips never yield a
//  personal name/kennitala — see ReceiptExtractionService's system prompt).
//
//  The "recent uploads" section here mirrors TransactionsListView's data
//  (limited to a few rows) — full history is one tap away via "Sjá allt".
//

import SwiftUI
import PhotosUI
import PDFKit
import Vision
import UIKit
import UniformTypeIdentifiers

struct CaptureView: View {
    @State private var docType: SourceDocumentType = .payslip
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var extracted: ExtractedTransaction?
    @State private var recentTransactions: [TransactionRecord] = []

    var body: some View {
        NavigationStack {
            ZStack {
                TaxIsTheme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Skanna")
                                .font(.title2.bold())
                                .foregroundStyle(TaxIsTheme.navy)
                            Text("Myndaðu eða veldu PDF af launaseðli eða reikningi — engin handinnsláttur.")
                                .font(.subheadline)
                                .foregroundStyle(TaxIsTheme.muted)
                        }

                        docTypePicker
                        primaryScanCard

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundStyle(TaxIsTheme.redText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }

                        HStack {
                            Text("Nýlegt")
                                .font(.headline)
                                .foregroundStyle(TaxIsTheme.text)
                            Spacer()
                            NavigationLink("Sjá allt") {
                                TransactionsListView()
                            }
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(TaxIsTheme.mintText)
                        }

                        if recentTransactions.isEmpty {
                            Text("Ekkert skannað enn")
                                .font(.subheadline)
                                .foregroundStyle(TaxIsTheme.muted)
                        } else {
                            ForEach(recentTransactions) { record in
                                recentRow(record)
                            }
                        }
                    }
                    .padding(18)
                    .padding(.top, 40)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { extracted != nil },
                set: { isPresented in if !isPresented { extracted = nil } }
            )) {
                if let extracted {
                    TransactionConfirmationView(transaction: extracted) {
                        self.extracted = nil
                        pickerItem = nil
                        Task { await loadRecent() }
                    }
                }
            }
        }
        .onChange(of: pickerItem) { _, newItem in
            guard let newItem else { return }
            Task { await processPhoto(item: newItem) }
        }
        .fileImporter(isPresented: $isShowingDocumentPicker, allowedContentTypes: [.pdf]) { result in
            switch result {
            case .success(let url):
                Task { await processPDF(url: url) }
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .task { await loadRecent() }
    }

    private var docTypePicker: some View {
        Picker("Tegund skjals", selection: $docType) {
            Text("Launaseðill").tag(SourceDocumentType.payslip)
            Text("Kvittun").tag(SourceDocumentType.receipt)
            Text("Reikningur").tag(SourceDocumentType.invoice)
        }
        .pickerStyle(.segmented)
        .disabled(isProcessing)
    }

    private var primaryScanCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 26))
                .foregroundStyle(TaxIsTheme.mint)
            Text(isProcessing ? "Les úr skjali..." : "Veldu mynd eða PDF")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaxIsTheme.text)
            Text(docTypeLabel)
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)

            if isProcessing {
                ProgressView().tint(TaxIsTheme.mint)
            } else {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        actionLabel("Mynd", icon: "photo")
                    }
                    Button {
                        isShowingDocumentPicker = true
                    } label: {
                        actionLabel("PDF", icon: "doc.fill")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.borderStrong, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
        )
        .disabled(isProcessing)
    }

    private var docTypeLabel: String {
        switch docType {
        case .payslip: return "Launaseðill"
        case .receipt: return "Kvittun"
        case .invoice: return "Verktakareikningur"
        }
    }

    private func actionLabel(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(TaxIsTheme.mint)
            .foregroundStyle(TaxIsTheme.onMint)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
    }

    private func recentRow(_ record: TransactionRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon(for: record))
                .font(.system(size: 13))
                .foregroundStyle(TaxIsTheme.mint)
                .frame(width: 28, height: 28)
                .background(TaxIsTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.vendorName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
                Text("\(record.totalAmountISK) kr. · \(ExtractedTransaction.dateOnlyFormatter.string(from: record.transactionDate))")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            statusBadge(for: record.extractionStatus)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func icon(for record: TransactionRecord) -> String {
        switch record.sourceDocumentType {
        case .payslip: return "creditcard.fill"
        case .invoice, .receipt: return "doc.text.fill"
        }
    }

    @ViewBuilder
    private func statusBadge(for status: ExtractionStatus) -> some View {
        switch status {
        case .confirmed:
            badge(text: "Staðfest", fg: TaxIsTheme.mint, bg: TaxIsTheme.mintTint, border: TaxIsTheme.mint.opacity(0.4))
        case .pendingReview:
            badge(text: "Yfirfara", fg: TaxIsTheme.red, bg: TaxIsTheme.red.opacity(0.08), border: TaxIsTheme.red.opacity(0.4))
        case .rejected:
            badge(text: "Hafnað", fg: TaxIsTheme.red, bg: TaxIsTheme.red.opacity(0.08), border: TaxIsTheme.red.opacity(0.4))
        }
    }

    private func badge(text: String, fg: Color, bg: Color, border: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
    }

    private func loadRecent() async {
        let fetched = (try? await SupabaseTransactionRepository.shared.fetchTransactions()) ?? []
        recentTransactions = Array(fetched.prefix(3))
    }

    private func processPhoto(item: PhotosPickerItem) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw ReceiptExtractionError.emptyInputText
            }
            let text = try await recognizeText(in: data)
            extracted = try await ReceiptExtractionService.shared.extractTransaction(
                fromRawText: text,
                sourceDocumentType: docType
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func processPDF(url: URL) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            guard
                let document = PDFDocument(url: url),
                let text = document.string,
                !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                throw ReceiptExtractionError.emptyInputText
            }
            extracted = try await ReceiptExtractionService.shared.extractTransaction(
                fromRawText: text,
                sourceDocumentType: docType
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func recognizeText(in imageData: Data) async throws -> String {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw ReceiptExtractionError.emptyInputText
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            do {
                try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

#Preview {
    CaptureView()
}
