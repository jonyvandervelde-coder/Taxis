import SwiftUI

// Combined income tab for blandað (hybrid) users.
// A compact segment picker is overlaid in the natural blank space above
// the embedded view's page header (.padding(.top, 40+18) gap).
struct BlandadTekjurView: View {
    @State private var segment: BSegment = .launasedlar
    @EnvironmentObject private var lm: LocalizationManager

    enum BSegment: CaseIterable { case launasedlar, tekjur }

    var body: some View {
        ZStack(alignment: .top) {
            switch segment {
            case .launasedlar: LaunasedlarView()
            case .tekjur:      TekjurView()
            }

            segmentPicker
                .padding(.horizontal, 18)
                .padding(.top, 8)
        }
    }

    private var segmentPicker: some View {
        HStack(spacing: 0) {
            ForEach(BSegment.allCases, id: \.self) { s in
                Button { segment = s } label: {
                    // Use "Verktakatekjur" (not "Tekjur") so this segment is never
                    // confused with the "Tekjur" bottom-nav tab in the full layout.
                    Text(s == .launasedlar
                         ? lm.t(.tabPayslips)
                         : (lm.language == .icelandic ? "Verktakatekjur" : lm.t(.tabRevenue))
                    )
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
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
}

#Preview {
    BlandadTekjurView()
        .environmentObject(LocalizationManager.shared)
        .environmentObject(SalariedJobStore())
        .environmentObject(VerktakiRevenueStore())
}
