import SwiftUI

struct MainTabView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var onboarding: OnboardingStore
    @EnvironmentObject private var lm: LocalizationManager
    @State private var selectedTab: Int = 2

    private var isSalaried:     Bool { onboarding.workerTypes.contains(.employee) }
    private var isContractor:   Bool { onboarding.workerTypes.contains(.contractor) }
    private var isHeimagisting: Bool { onboarding.workerTypes.contains(.heimagisting) }
    private var isBlandad:      Bool { isSalaried && isContractor }
    private var hasOtherIncome: Bool { isSalaried || isContractor }

    var body: some View {
        ZStack(alignment: .bottom) {
            currentPage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 72)

            CustomTabBar(selected: $selectedTab, config: tabConfig)
        }
        .ignoresSafeArea(edges: .bottom)
    }

    @ViewBuilder
    private var currentPage: some View {
        switch selectedTab {
        case 0: leftView1
        case 1: leftView2
        case 2: HomeView(onboarding: onboarding)
        case 3: FærslurView()
        default: ProfileView(session: session, onboarding: onboarding)
        }
    }

    @ViewBuilder private var leftView1: some View {
        if isHeimagisting && !hasOtherIncome {
            HeimagistingView()
        } else if isBlandad {
            BlandadTekjurView()
        } else if isSalaried {
            LaunasedlarView()
        } else if isContractor {
            TekjurView()
        } else {
            UtgjoldView()
        }
    }

    @ViewBuilder private var leftView2: some View {
        if isHeimagisting && hasOtherIncome {
            HeimagistingView()
        } else {
            UtgjoldView()
        }
    }

    private var tabConfig: TabConfig {
        let left1: TabDef
        if isHeimagisting && !hasOtherIncome {
            left1 = TabDef(icon: "house.fill", label: "Heimagisting")
        } else if isBlandad {
            left1 = TabDef(icon: "briefcase.fill", label: lm.t(.income))
        } else if isSalaried {
            left1 = TabDef(icon: "doc.text", label: lm.t(.tabPayslips))
        } else if isContractor {
            left1 = TabDef(icon: "chart.line.uptrend.xyaxis", label: lm.t(.tabRevenue))
        } else {
            left1 = TabDef(icon: "bag", label: lm.t(.tabExpenses))
        }

        let left2: TabDef = isHeimagisting && hasOtherIncome
            ? TabDef(icon: "house.fill", label: "Heimagisting")
            : TabDef(icon: "bag",        label: lm.t(.tabExpenses))

        return TabConfig(
            left1:  left1,
            left2:  left2,
            center: TabDef(icon: "house.fill",         label: lm.t(.tabHome)),
            right1: TabDef(icon: "lightbulb",          label: lm.t(.tabInsights)),
            right2: TabDef(icon: "person.crop.circle", label: lm.t(.tabSettings))
        )
    }
}

// MARK: - Tab config

struct TabDef {
    let icon: String
    let label: String
}

struct TabConfig {
    let left1, left2, center, right1, right2: TabDef
    var all: [TabDef] { [left1, left2, center, right1, right2] }
}

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selected: Int
    let config: TabConfig

    private let barHeight: CGFloat = 56
    private let bottomPad: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottom) {
            // Solid dark background matching app theme
            Rectangle()
                .fill(TaxIsTheme.bg)
                .frame(height: barHeight + bottomPad + 20)
                .overlay(
                    Rectangle()
                        .fill(TaxIsTheme.border)
                        .frame(height: 0.5),
                    alignment: .top
                )

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(Array(config.all.enumerated()), id: \.offset) { idx, tab in
                    if idx == 2 {
                        centerButton(tab)
                    } else {
                        regularButton(tab, index: idx)
                    }
                }
            }
            .padding(.bottom, bottomPad)
        }
        .frame(maxWidth: .infinity)
    }

    private func regularButton(_ tab: TabDef, index: Int) -> some View {
        Button { selected = index } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.icon)
                    .font(.system(size: 19))
                    .foregroundStyle(selected == index ? TaxIsTheme.mint : TaxIsTheme.muted)
                Text(tab.label)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(selected == index ? TaxIsTheme.mint : TaxIsTheme.muted)
            }
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func centerButton(_ tab: TabDef) -> some View {
        Button { selected = 2 } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(TaxIsTheme.mint)
                        .frame(width: 54, height: 54)
                        .shadow(color: TaxIsTheme.mint.opacity(0.4), radius: 8, y: -2)
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(TaxIsTheme.onMint)
                }
                .offset(y: -4)

                Text(tab.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(selected == 2 ? TaxIsTheme.mint : TaxIsTheme.muted)
                    .offset(y: -2)
            }
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
