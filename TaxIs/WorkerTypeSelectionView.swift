//
//  WorkerTypeSelectionView.swift
//  TaxÍs
//
//  First onboarding step: two toggleable buttons, launþegi and verktaki.
//  Selecting one picks that path; selecting both means both paths run
//  (payslip capture, then manual income entry).
//

import SwiftUI

struct WorkerTypeSelectionView: View {
    @ObservedObject var onboarding: OnboardingStore
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()

            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Which best describes you?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.navy)
                    Text("Choose one or both — this decides how TaxÍs collects your income.")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.body)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    ForEach(WorkerType.allCases, id: \.self) { type in
                        toggleButton(for: type)
                    }
                }
                .padding(.horizontal, 32)

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(onboarding.workerTypes.isEmpty ? TaxIsTheme.muted : TaxIsTheme.mint)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(onboarding.workerTypes.isEmpty)
                .padding(.horizontal, 32)
            }
        }
    }

    private func toggleButton(for type: WorkerType) -> some View {
        let isSelected = onboarding.workerTypes.contains(type)
        return Button {
            onboarding.toggle(type)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.subheadline.weight(.semibold))
                    Text(type.subtitle)
                        .font(.footnote)
                        .foregroundStyle(isSelected ? TaxIsTheme.onMint : TaxIsTheme.muted)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TaxIsTheme.mint)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TaxIsTheme.mintTint : TaxIsTheme.card)
            .foregroundStyle(isSelected ? TaxIsTheme.mintText : TaxIsTheme.text)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(isSelected ? TaxIsTheme.mint : TaxIsTheme.border, lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkerTypeSelectionView(onboarding: OnboardingStore()) {}
}
