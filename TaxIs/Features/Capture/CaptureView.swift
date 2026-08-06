//
//  CaptureView.swift
//  TaxÍs
//
//  "Skanna" tab — Launaseðill only (Kvittun and Reikningur removed).
//  Photo or PDF → text (Vision OCR for photos; PDFKit text layer for
//  text-based PDFs; Vision OCR fallback for image-based PDFs) →
//  ReceiptExtractionService (Claude via Edge Function) →
//  TransactionConfirmationView.
//
//  The "Slá inn handvirkt" path presents ManualPayslipEntryView and
//  feeds its result into the same confirmation flow.
//

import SwiftUI
import PhotosUI
import PDFKit
import Vision
import UIKit
import UniformTypeIdentifiers

struct CaptureView: View {
    @State private var pickerItem: PhotosPickerItem?
    @State private var isShowingDocumentPicker = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showManualEntry = false
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
                            Text("Myndaðu eða veldu PDF af launaseðlinum þínum.")
                                .font(.subheadline)
                                .foregroundStyle(TaxIsTheme.muted)
                        }

                        primaryScanCard

                        if let errorMessage {
                            errorCard(message: errorMessage)
                        }

                        // Manual entry shortcut
                        Button {
                            showManualEntry = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.pencil")
                                    .font(.subheadline)
                                Text("Slá inn handvirkt")
                                    .font(.subheadline.weight(.medium))
                            }
                            .foregroundStyle(TaxIsTheme.mintText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(TaxIsTheme.mintTint)
                            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                    .strokeBorder(TaxIsTheme.mint.opacity(0.35), lineWidth: 1)
                            )
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
                    .padding(.top, 8)
                    .safeAreaPadding(.top)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { extracted != nil },
                set: { if !$0 { extracted = nil } }
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
        .fileImporter(
            isPresented: $isShowingDocumentPicker,
            allowedContentTypes: [.pdf]
        ) { result in
            switch result {
            case .success(let url): Task { await processPDF(url: url) }
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .sheet(isPresented: $showManualEntry) {
            ManualPayslipEntryView { transaction in
                extracted = transaction
            }
        }
        .task { await loadRecent() }
    }

    // MARK: - Scan card

    private var primaryScanCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 26))
                .foregroundStyle(TaxIsTheme.mint)

            Text(isProcessing ? "Les úr skjali..." : "Veldu mynd eða PDF")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TaxIsTheme.text)

            Text("Launaseðill")
                .font(.footnote)
                .foregroundStyle(TaxIsTheme.muted)

            if isProcessing {
                ProgressView().tint(TaxIsTheme.mint)
            } else {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $pickerItem, matching: .images) {
                        actionLabel("Mynd", icon: "photo")
                    }
                    Button { isShowingDocumentPicker = true } label: {
                        actionLabel("PDF", icon: "doc.fill")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(
                    TaxIsTheme.borderStrong,
                    style: StrokeStyle(lineWidth: 1.5, dash: [5])
                )
        )
        .disabled(isProcessing)
    }

    // MARK: - Error card with manual entry fallback

    private func errorCard(message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(TaxIsTheme.amber)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.text)
            }
            Button {
                errorMessage = nil
                showManualEntry = true
            } label: {
                Text("Handvirk skráning")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.mint)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.amberTint)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                .strokeBorder(TaxIsTheme.amberBorder, lineWidth: 1)
        )
    }

    // MARK: - Recent row

    private func recentRow(_ record: TransactionRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "creditcard.fill")
                .font(.system(size: 13))
                .foregroundStyle(TaxIsTheme.mint)
                .frame(width: 28, height: 28)
                .background(TaxIsTheme.bg)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(record.vendorName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
                Text(verbatim: "\(NSDecimalNumber(decimal: record.totalAmountISK).intValue) kr. · \(ExtractedTransaction.dateOnlyFormatter.string(from: record.transactionDate))")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            statusBadge(for: record.extractionStatus)
        }
        .padding(.horizontal, 13).padding(.vertical, 11)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusBadge(for status: ExtractionStatus) -> some View {
        switch status {
        case .confirmed:
            badge(text: "Staðfest",  fg: TaxIsTheme.mint,  bg: TaxIsTheme.mintTint,        border: TaxIsTheme.mint.opacity(0.4))
        case .pendingReview:
            badge(text: "Yfirfara",  fg: TaxIsTheme.red,   bg: TaxIsTheme.red.opacity(0.08), border: TaxIsTheme.red.opacity(0.4))
        case .rejected:
            badge(text: "Hafnað",    fg: TaxIsTheme.red,   bg: TaxIsTheme.red.opacity(0.08), border: TaxIsTheme.red.opacity(0.4))
        }
    }

    private func badge(text: String, fg: Color, bg: Color, border: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .foregroundStyle(fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: 1))
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

    // MARK: - Processing

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
                sourceDocumentType: .payslip
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// PDFs first try the text layer (fast, zero-OCR). If the text layer is
    /// empty (scanned / image-based PDF), falls back to Vision OCR on each page.
    private func processPDF(url: URL) async {
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        do {
            let didAccess = url.startAccessingSecurityScopedResource()
            defer { if didAccess { url.stopAccessingSecurityScopedResource() } }

            guard let document = PDFDocument(url: url) else {
                throw ReceiptExtractionError.emptyInputText
            }

            // Try text layer first
            var rawText = document.string?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            // Fall back to Vision OCR page-by-page for image-based PDFs
            if rawText.isEmpty {
                var lines: [String] = []
                for pageIndex in 0..<document.pageCount {
                    guard let page = document.page(at: pageIndex) else { continue }
                    let pageImage = page.thumbnail(of: CGSize(width: 1200, height: 1600), for: .mediaBox)
                    guard let cgImage = pageImage.cgImage else { continue }
                    let pageText = try await recognizeText(cgImage: cgImage)
                    lines.append(pageText)
                }
                rawText = lines.joined(separator: "\n")
            }

            guard !rawText.isEmpty else { throw ReceiptExtractionError.emptyInputText }

            extracted = try await ReceiptExtractionService.shared.extractTransaction(
                fromRawText: rawText,
                sourceDocumentType: .payslip
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Vision OCR helpers

    private func recognizeText(in imageData: Data) async throws -> String {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            throw ReceiptExtractionError.emptyInputText
        }
        return try await recognizeText(cgImage: cgImage)
    }

    private func recognizeText(cgImage: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { req, error in
                if let error { continuation.resume(throwing: error); return }
                let observations = req.results as? [VNRecognizedTextObservation] ?? []
                let text = observations
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n")
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["is", "en"]

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
