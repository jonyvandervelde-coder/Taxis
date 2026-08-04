import SwiftUI

struct MainTabView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var onboarding: OnboardingStore
    @EnvironmentObject private var lm: LocalizationManager
    @State private var selectedTab: Int = 2

    private var isSalaried:        Bool { onboarding.workerTypes.contains(.employee) }
    private var isContractor:      Bool { onboarding.workerTypes.contains(.contractor) }
    private var isHeimagisting:    Bool { onboarding.workerTypes.contains(.heimagisting) }
    private var isBlandad:         Bool { isSalaried && isContractor }
    private var hasOtherIncome:    Bool { isSalaried || isContractor }
    private var isHeimagistingOnly: Bool { isHeimagisting && !isSalaried && !isContractor }

    // Compact = single-type worker who needs only one feature tab
    private var isCompact: Bool {
        (isSalaried && !isContractor && !isHeimagisting) || isHeimagistingOnly
    }

    private var centerTabIndex: Int { isCompact ? 1 : 2 }

    var body: some View {
        ZStack(alignment: .bottom) {
            currentPage
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.bottom, 72)

            CustomTabBar(selected: $selectedTab, config: tabConfig)
        }
        .ignoresSafeArea(edges: .bottom)
        .onAppear {
            if isCompact && selectedTab == 2 { selectedTab = 1 }
        }
    }

    @ViewBuilder
    private var currentPage: some View {
        if isHeimagistingOnly {
            switch selectedTab {
            case 0:  HeimagistingView()
            case 2:  ProfileView(session: session, onboarding: onboarding)
            default: HomeView(onboarding: onboarding)
            }
        } else if isCompact {
            switch selectedTab {
            case 0:  compactFeatureView
            case 1:  HomeView(onboarding: onboarding)
            case 2:  FærslurView()
            default: ProfileView(session: session, onboarding: onboarding)
            }
        } else {
            switch selectedTab {
            case 0:  leftView1
            case 1:  leftView2
            case 2:  HomeView(onboarding: onboarding)
            case 3:  FærslurView()
            default: ProfileView(session: session, onboarding: onboarding)
            }
        }
    }

    @ViewBuilder private var compactFeatureView: some View {
        if isHeimagisting { HeimagistingView() }
        else              { LaunasedlarView()  }
    }

    @ViewBuilder private var leftView1: some View {
        if isBlandad                         { BlandadTekjurView() }
        else if isSalaried && isHeimagisting { LaunasedlarView()   }
        else if isContractor                 { TekjurView()        }
        else                                 { HomeView(onboarding: onboarding) }
    }

    @ViewBuilder private var leftView2: some View {
        if isHeimagisting && hasOtherIncome { HeimagistingView() }
        else                                { UtgjoldView()      }
    }

    private var tabConfig: TabConfig {
        if isHeimagistingOnly {
            return .compact3(
                left:   TabDef(icon: "bed.double.fill",      label: "Heimagisting"),
                center: TabDef(icon: "house.fill",           label: lm.t(.tabHome)),
                right:  TabDef(icon: "person.crop.circle",  label: lm.t(.tabSettings))
            )
        }
        if isCompact {
            let feature: TabDef = isHeimagisting
                ? TabDef(icon: "bed.double.fill", label: "Heimagisting")
                : TabDef(icon: "doc.text",        label: lm.t(.tabPayslips))
            return .compact(
                feature: feature,
                center:  TabDef(icon: "house.fill",         label: lm.t(.tabHome)),
                right1:  TabDef(icon: "lightbulb",          label: lm.t(.tabInsights)),
                right2:  TabDef(icon: "person.crop.circle", label: lm.t(.tabSettings))
            )
        }

        let left1: TabDef
        if isBlandad {
            left1 = TabDef(icon: "briefcase.fill",             label: lm.t(.income))
        } else if isSalaried && isHeimagisting {
            left1 = TabDef(icon: "doc.text",                   label: lm.t(.tabPayslips))
        } else if isContractor {
            left1 = TabDef(icon: "chart.line.uptrend.xyaxis",  label: lm.t(.tabRevenue))
        } else {
            left1 = TabDef(icon: "house.fill",                 label: "Heimagisting")
        }

        let left2: TabDef = isHeimagisting && hasOtherIncome
            ? TabDef(icon: "house.fill", label: "Heimagisting")
            : TabDef(icon: "bag",        label: lm.t(.tabExpenses))

        return .standard(
            left1,
            left2,
            TabDef(icon: "house.fill",         label: lm.t(.tabHome)),
            TabDef(icon: "lightbulb",          label: lm.t(.tabInsights)),
            TabDef(icon: "person.crop.circle", label: lm.t(.tabSettings))
        )
    }
}

// MARK: - Tab config

struct TabDef {
    let icon: String
    let label: String
}

struct TabConfig {
    let items: [TabDef]
    let centerIndex: Int

    static func standard(_ l1: TabDef, _ l2: TabDef, _ c: TabDef, _ r1: TabDef, _ r2: TabDef) -> TabConfig {
        TabConfig(items: [l1, l2, c, r1, r2], centerIndex: 2)
    }
    static func compact3(left: TabDef, center: TabDef, right: TabDef) -> TabConfig {
        TabConfig(items: [left, center, right], centerIndex: 1)
    }
    static func compact(feature: TabDef, center: TabDef, right1: TabDef, right2: TabDef) -> TabConfig {
        TabConfig(items: [feature, center, right1, right2], centerIndex: 1)
    }
}

// MARK: - Custom tab bar

struct CustomTabBar: View {
    @Binding var selected: Int
    let config: TabConfig

    private let barHeight: CGFloat = 56
    private let bottomPad: CGFloat = 20

    var body: some View {
        ZStack(alignment: .bottom) {
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
                ForEach(Array(config.items.enumerated()), id: \.offset) { idx, tab in
                    if idx == config.centerIndex {
                        centerButton(tab, index: idx)
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

    private func centerButton(_ tab: TabDef, index: Int) -> some View {
        let isActive = selected == index
        return Button { selected = index } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(isActive ? TaxIsTheme.mint : TaxIsTheme.card)
                        .frame(width: 54, height: 54)
                        .overlay(
                            Circle().strokeBorder(
                                isActive ? Color.clear : TaxIsTheme.borderStrong,
                                lineWidth: 1.5
                            )
                        )
                        .shadow(
                            color: isActive ? TaxIsTheme.mint.opacity(0.35) : Color.clear,
                            radius: 8, y: -2
                        )
                    Image(systemName: tab.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(isActive ? TaxIsTheme.onMint : TaxIsTheme.muted)
                }
                .offset(y: -4)

                Text(tab.label)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(selected == index ? TaxIsTheme.mint : TaxIsTheme.muted)
                    .offset(y: -2)
            }
            .frame(height: barHeight)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
