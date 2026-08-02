import SwiftUI

struct WorkerTypeSelectionView: View {
    @ObservedObject var onboarding: OnboardingStore
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text("Hvernig færðu tekjur?")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.navy)
                    Text("Veldu eitt eða fleiri — þetta ákvarðar hvernig TaxÍs reiknar skatta þína.")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)

                VStack(spacing: 10) {
                    ForEach(WorkerType.allCases, id: \.self) { type in
                        toggleButton(for: type)
                    }
                }
                .padding(.horizontal, 28)

                Button {
                    onContinue()
                } label: {
                    Text("Halda áfram")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(onboarding.workerTypes.isEmpty ? TaxIsTheme.muted : TaxIsTheme.mint)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .disabled(onboarding.workerTypes.isEmpty)
                .padding(.horizontal, 28)
            }
        }
    }

    private func toggleButton(for type: WorkerType) -> some View {
        let isSelected = onboarding.workerTypes.contains(type)
        return Button {
            onboarding.toggle(type)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: type.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? TaxIsTheme.mint : TaxIsTheme.muted)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(type.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? TaxIsTheme.mintText : TaxIsTheme.text)
                    Text(type.subtitle)
                        .font(.footnote)
                        .foregroundStyle(isSelected ? TaxIsTheme.mintText.opacity(0.8) : TaxIsTheme.muted)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? TaxIsTheme.mint : TaxIsTheme.border)
                    .font(.system(size: 20))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? TaxIsTheme.mintTint : TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(isSelected ? TaxIsTheme.mint : TaxIsTheme.border,
                                  lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    WorkerTypeSelectionView(onboarding: OnboardingStore()) {}
}
