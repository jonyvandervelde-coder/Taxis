//
//  HomeView.swift
//  TaxÍs
//
//  Dashboard tab. Two layers of calculation:
//    1. Deterministic — runs immediately from local stores (SalariedJobStore
//       for launþegi, VerktakiRevenueStore+VerktakiExpenseStore for verktaki).
//       No network needed. Always shown when the user has entered data.
//    2. AI estimate — TaxInsightsService one-shot call, shown below as
//       "Innsýn". Falls back gracefully when backend is unavailable.
//

import SwiftUI

// MARK: - Shared types

struct BasisLine: Identifiable {
    let id = UUID()
    let label: String
    let value: String
}

struct DashboardNotification: Identifiable {
    let id: String
    let icon: String
    let iconBg: Color
    let iconTint: Color
    let title: String
    let preview: String
    let body: String
    let cta: String
    let basis: [BasisLine]
}

extension DashboardNotification {
    static let demoList: [DashboardNotification] = []
}

// MARK: - Home

struct HomeView: View {
    @ObservedObject var onboarding: OnboardingStore
    @EnvironmentObject private var salariedStore: SalariedJobStore
    @EnvironmentObject private var revenueStore: VerktakiRevenueStore
    @EnvironmentObject private var expenseStore: VerktakiExpenseStore
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var ledgerStore: TaxLedgerStore
    @EnvironmentObject private var payslipStore: PayslipStore
    @State private var selectedNotification: DashboardNotification?
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var settlement: SettlementEstimate?
    @State private var insights: [DashboardNotification] = []

    private var isSalaried:     Bool { onboarding.workerTypes.contains(.employee) }
    private var isContractor:   Bool { onboarding.workerTypes.contains(.contractor) }
    private var isHeimagisting: Bool { onboarding.workerTypes.contains(.heimagisting) }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    if isHeimagisting && !isSalaried && !isContractor {
                        heimagistingDashboard
                    } else {
                        overviewCard

                        Rectangle().fill(TaxIsTheme.border).frame(height: 1).padding(.vertical, 4)

                        Text("Innsýn")
                            .font(.headline)
                            .foregroundStyle(TaxIsTheme.text)

                        if isLoading {
                            loadingCard
                        } else if let loadError {
                            errorCard(loadError)
                        } else if let settlement {
                            SettlementHeroCard(settlement: settlement)
                            if !insights.isEmpty {
                                ForEach(insights) { n in
                                    NotificationRow(notification: n) { selectedNotification = n }
                                }
                            }
                        } else {
                            aiEmptyCard
                        }
                    }
                }
                .padding(18)
                .padding(.top, 40)
            }
        }
        .sheet(item: $selectedNotification) { n in
            NotificationDetailSheet(notification: n) { selectedNotification = nil }
        }
        // Refresh payslip totals every time this tab appears (HomeView is
        // recreated on each tab switch, so .task is equivalent to .onAppear).
        .task {
            async let payslips: () = payslipStore.refresh()
            async let insights: () = loadInsights()
            _ = await (payslips, insights)
            if isHeimagisting && !isSalaried && !isContractor { await ledgerStore.load() }
        }
        .refreshable {
            await payslipStore.refresh()
            await loadInsights()
            if isHeimagisting && !isSalaried && !isContractor { await ledgerStore.load() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                let firstName = profileStore.displayName.isEmpty
                    ? nil
                    : profileStore.displayName.components(separatedBy: " ").first
                Text(firstName.map { "Hæ, \($0)" } ?? "Hæ")
                    .font(.title2.bold())
                    .foregroundStyle(TaxIsTheme.navy)
                Text(monthLabel)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(TaxIsTheme.card)
                    .overlay(Circle().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
                Text(profileStore.initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.mint)
            }
            .frame(width: 38, height: 38)
        }
    }

    // MARK: - Heimagisting-only dashboard

    private var heimagistingDashboard: some View {
        let m = ledgerStore.metrics
        let calc = HeimagistingCalc(
            grossTotal: m.grossTotal,
            nightsUsed: m.nightsUsed,
            cliffTriggered: m.cliffTriggered
        )
        return Group {
            // ÞAKMÖRK card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("ÞAKMÖRK 2026")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.muted)
                    Spacer()
                    let triggered = calc.cliffTriggered
                    Text(triggered ? "ÞAKI NÁÐ" : "Öruggt")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(triggered ? TaxIsTheme.redText : TaxIsTheme.mint)
                        .padding(.horizontal, 9).padding(.vertical, 3)
                        .background((triggered ? TaxIsTheme.redText : TaxIsTheme.mint).opacity(0.1))
                        .clipShape(Capsule())
                }
                heimProgressRow(icon: "moon.stars.fill",
                                label: "Nætur", detail: "\(calc.nightsUsed) af 90",
                                remaining: "\(calc.nightsRemaining) eftir",
                                fraction: calc.nightsFraction, warn: calc.nightsFraction >= 0.8)
                heimProgressRow(icon: "banknote",
                                label: "Tekjur", detail: fmtShortH(calc.grossTotal) + " af 2M",
                                remaining: fmtShortH(m.allowanceRemaining) + " eftir",
                                fraction: calc.incomeFraction, warn: calc.incomeFraction >= 0.8)
                if calc.cliffTriggered {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(TaxIsTheme.redText).font(.caption)
                        Text("Þak náð — tekjur renna inn í persónulega skattstiga.")
                            .font(.caption).foregroundStyle(TaxIsTheme.muted)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(16)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(calc.cliffTriggered ? TaxIsTheme.redText.opacity(0.5) : TaxIsTheme.border, lineWidth: 1))

            // SKATTAÚTREIKNINGUR card
            VStack(alignment: .leading, spacing: 0) {
                Text("SKATTAÚTREIKNINGUR")
                    .font(.caption.weight(.semibold)).foregroundStyle(TaxIsTheme.muted)
                    .padding(.horizontal, 15).padding(.top, 13).padding(.bottom, 10)
                heimCalcRow(label: "Heildartekjur", value: fmtISKH(calc.grossTotal), divider: true)
                heimCalcRow(label: "Gistináttaskattur (\(calc.nightsUsed) × 800 kr.)",
                            value: "− \(fmtISKH(calc.lodgingTax))", divider: true)
                if let reserve = calc.capitalTaxReserve {
                    heimCalcRow(label: "22% fjármagnstekjuskattur",
                                value: "− \(fmtISKH(reserve))", divider: true)
                } else {
                    HStack {
                        Text("Persónulegur skattstigi").font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                        Spacer()
                        Text("Þak náð").font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.redText)
                    }
                    .padding(.horizontal, 15).padding(.vertical, 10)
                    Divider().background(TaxIsTheme.border)
                }
                HStack {
                    Text("Leggja til hliðar").font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Text(fmtISKH(calc.totalSetAside)).font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.mint)
                }
                .padding(.horizontal, 15).padding(.vertical, 12)
            }
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
    }

    private func heimProgressRow(icon: String, label: String, detail: String, remaining: String, fraction: Double, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.caption2).foregroundStyle(warn ? TaxIsTheme.redText : TaxIsTheme.mint)
                Text("\(label): \(detail)").font(.caption).foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(remaining).font(.caption.weight(.semibold)).foregroundStyle(warn ? TaxIsTheme.redText : TaxIsTheme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(TaxIsTheme.border.opacity(0.5))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(warn ? TaxIsTheme.redText : TaxIsTheme.mint)
                        .frame(width: geo.size.width * CGFloat(min(fraction, 1.0)))
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 6)
        }
    }

    private func heimCalcRow(label: String, value: String, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.text)
            }
            .padding(.horizontal, 15).padding(.vertical, 10)
            if divider { Divider().background(TaxIsTheme.border) }
        }
    }

    private func fmtISKH(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))") kr."
    }

    private func fmtShortH(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0fk", v / 1_000) }
        return "\(Int(v))"
    }

    // MARK: - Overview card

    private var overviewCard: some View {
        VStack(spacing: 0) {
            if isSalaried {
                // Source of truth: confirmed payslip rows from Supabase,
                // keyed to the current calendar month. Never re-triggers OCR.
                let total = payslipStore.currentMonthGross
                overviewRow(
                    icon: "doc.text",
                    label: "Launagreiðslur þennan mánuð",
                    value: total > 0 ? formatISK(total) : "—",
                    showDivider: isContractor
                )
            }
            if isContractor {
                let rev = revenueStore.currentMonthTotal
                let expenses = expenseStore.totalThisMonth
                overviewRow(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Verktakatekjur þennan mánuð",
                    value: rev > 0 ? formatISK(rev) : "—",
                    showDivider: true
                )
                let retentionNeeded: Decimal = rev > 0
                    ? TaxCalculationEngine.calculateContractor(
                        grossRevenueISK: rev, totalExpensesISK: expenses
                    ).totalRetentionISK
                    : 0
                overviewRow(
                    icon: "shield.fill",
                    label: "Til hliðar (skattar o.fl.)",
                    value: retentionNeeded > 0 ? formatISK(retentionNeeded) : "—",
                    showDivider: false
                )
            }
            if isHeimagisting && !isSalaried && !isContractor {
                let m = ledgerStore.metrics
                let lodgingTax   = Double(m.nightsUsed) * 800
                let capitalTax   = m.cliffTriggered ? 0.0 : m.grossTotal * 0.22
                let totalSetAside = lodgingTax + capitalTax
                overviewRow(
                    icon: "moon.fill",
                    label: "Nætur leigðar (af 90)",
                    value: "\(m.nightsUsed) · \(max(0, 90 - m.nightsUsed)) eftir",
                    showDivider: true
                )
                overviewRow(
                    icon: "shield.fill",
                    label: "Leggja til hliðar",
                    value: totalSetAside > 0 ? formatISK(Decimal(totalSetAside)) : "0 kr.",
                    showDivider: false
                )
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func overviewRow(icon: String, label: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.mint)
                    .frame(width: 20)
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                if !value.isEmpty {
                    Text(value)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.text)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            if showDivider { Divider().background(TaxIsTheme.border) }
        }
    }

    private var monthLabel: String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "is_IS")
        return f.string(from: Date()).capitalized
    }

    // MARK: - Profile picker

    private var profilePicker: some View {
        HStack(spacing: 0) {
            profileChip("Launþegi", types: [.employee])
            profileChip("Blandað",  types: [.employee, .contractor])
            profileChip("Verktaki", types: [.contractor])
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func profileChip(_ label: String, types: Set<WorkerType>) -> some View {
        let selected = onboarding.workerTypes == types
        return Button {
            onboarding.setWorkerTypes(types)
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(selected ? TaxIsTheme.mint : Color.clear)
                .foregroundStyle(selected ? TaxIsTheme.onMint : TaxIsTheme.muted)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control - 1))
        }
        .buttonStyle(.plain)
        .padding(2)
    }

    // MARK: - AI section

    private var loadingCard: some View {
        VStack(spacing: 10) {
            ProgressView().tint(TaxIsTheme.mint)
            Text("Fer yfir gögnin þín…")
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
    }

    private func errorCard(_ message: String) -> some View {
        Text(message)
            .font(.footnote)
            .foregroundStyle(TaxIsTheme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var aiEmptyCard: some View {
        Text("Bættu við gögnum á Launaseðlum eða Tekjum til að fá ábendingar hér.")
            .font(.footnote)
            .foregroundStyle(TaxIsTheme.muted)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func loadInsights() async {
        // No session token → debug bypass or not signed in. Show empty prompt, skip silently.
        guard (try? SupabaseSession.currentAccessToken()) != nil else { return }

        isLoading = true
        loadError = nil
        defer { isLoading = false }
        do {
            let transactions = try await SupabaseTransactionRepository.shared.fetchTransactions()
            guard !transactions.isEmpty else { return }
            let result = try await TaxInsightsService.shared.generateInsights(
                transactions: transactions,
                workerTypes: onboarding.workerTypes
            )
            settlement = result.settlement
            insights   = result.insights
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Settlement hero card (AI)

private struct SettlementHeroCard: View {
    let settlement: SettlementEstimate

    private var badge: (label: String, color: Color) {
        switch settlement.outcome {
        case .debt:          return ("Áætlaður mismunur", TaxIsTheme.red)
        case .reimbursement: return ("Áætluð endurgreiðsla", TaxIsTheme.mint)
        case .breakEven:     return ("Í jafnvægi", TaxIsTheme.muted)
        }
    }

    private var bodyText: String {
        switch settlement.outcome {
        case .debt:
            let amt = formatISK(abs(settlement.netPositionISK))
            return "Samkvæmt skráðum upplýsingum gæti vantað um \(amt) upp á staðgreiðslu."
        case .reimbursement:
            return "Áætluð endurgreiðsla við álagningu: \(formatISK(settlement.netPositionISK))."
        case .breakEven:
            return "Staðgreiðsla virðist vera í jafnvægi við væntanlega álagningu."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("ÁÆTLUÐ STAÐA VIÐ ÁLAGNINGU")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                HStack(spacing: 6) {
                    Circle().fill(badge.color).frame(width: 6, height: 6)
                    Text(badge.label)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(badge.color)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(badge.color.opacity(0.08))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(badge.color.opacity(0.4), lineWidth: 1))
            }

            Text(formatISK(abs(settlement.netPositionISK)))
                .font(.largeTitle.bold())
                .foregroundStyle(TaxIsTheme.text)
                .accessibilityLabel(badge.label + ": " + formatISK(abs(settlement.netPositionISK)))

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(TaxIsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)

            Text("Vikmörk: ±\(formatISK(settlement.confidenceBandISK)) · \(settlement.headlineNote)")
                .font(.caption)
                .foregroundStyle(TaxIsTheme.muted.opacity(0.8))

            TaxBracketChart(
                combinedTaxable: NSDecimalNumber(decimal: settlement.projectedAnnualCombinedTaxableISK).doubleValue
            )
            .padding(.top, 8)

            // Calculation provenance footer
            Divider().background(TaxIsTheme.border).padding(.top, 4)
            HStack(spacing: 6) {
                Text("Útreikningsár: 2026")
                Text("·")
                Text("Síðast uppfært: ágúst 2026")
                Spacer(minLength: 0)
                Link("Skatturinn.is ↗", destination: URL(string: "https://www.skatturinn.is/einstaklingar/")!)
                    .foregroundStyle(TaxIsTheme.mintText)
            }
            .font(.caption2)
            .foregroundStyle(TaxIsTheme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }
}

// MARK: - Bracket chart

private struct TaxBracketChart: View {
    let combinedTaxable: Double
    private let domainMax: Double  = 1_600_000
    private let bracket1: Double   = 498_122
    private let bracket2: Double   = 1_398_450

    private func fraction(_ v: Double) -> CGFloat { CGFloat(min(v / domainMax, 1.0)) }

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(TaxIsTheme.bg)
                    Capsule().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
                    Rectangle().fill(TaxIsTheme.borderStrong).frame(width: 1)
                        .offset(x: geo.size.width * fraction(bracket1))
                    Rectangle().fill(TaxIsTheme.borderStrong).frame(width: 1)
                        .offset(x: geo.size.width * fraction(bracket2))
                    Capsule().fill(TaxIsTheme.mint)
                        .frame(width: geo.size.width * fraction(combinedTaxable))
                        .shadow(color: TaxIsTheme.mint.opacity(0.65), radius: 6)
                    Rectangle().fill(TaxIsTheme.text).frame(width: 2)
                        .offset(x: max(0, geo.size.width * fraction(combinedTaxable) - 1))
                }
            }
            .frame(height: 14)
            HStack {
                Text("0"); Spacer()
                Text("498.122"); Spacer()
                Text("1.398.450"); Spacer()
                Text("1,6m+")
            }
            .font(.caption2).foregroundStyle(TaxIsTheme.muted)
        }
    }
}

// MARK: - Notification rows

private struct NotificationRow: View {
    let notification: DashboardNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: notification.icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(notification.iconTint)
                    .frame(width: 30, height: 30)
                    .background(notification.iconBg)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.text)
                    Text(notification.preview)
                        .font(.footnote)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                Spacer(minLength: 0)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

private struct NotificationDetailSheet: View {
    let notification: DashboardNotification
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            TaxIsTheme.card.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Text(notification.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
                Text(notification.body)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                if !notification.basis.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REIKNINGSGRUNDVÖLLUR")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TaxIsTheme.muted)
                        ForEach(notification.basis) { line in
                            HStack {
                                Text(line.label).foregroundStyle(TaxIsTheme.muted)
                                Spacer()
                                Text(line.value).foregroundStyle(TaxIsTheme.text).fontWeight(.bold)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(12)
                    .background(TaxIsTheme.inputBg)
                    .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                    .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
                }

                Button(action: onDismiss) {
                    Text(notification.cta)
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(TaxIsTheme.mint)
                        .foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
            }
            .padding(20)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Shared ISK formatter (used by DeductionsView too)

func formatISKShort(_ value: Double) -> String {
    if value >= 1_000_000 { return String(format: "%.1fM", value / 1_000_000) }
    if value >= 1_000     { return String(format: "%.0fk", value / 1_000) }
    return "\(Int(value))"
}

func formatISK(_ value: Decimal) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.groupingSeparator = "."
    f.decimalSeparator = ","
    f.maximumFractionDigits = 0
    f.usesGroupingSeparator = true
    let s = f.string(from: NSDecimalNumber(decimal: value)) ?? "\(value)"
    return "\(s) kr."
}

#Preview {
    HomeView(onboarding: OnboardingStore())
        .environmentObject(SalariedJobStore())
        .environmentObject(VerktakiRevenueStore())
        .environmentObject(VerktakiExpenseStore())
        .environmentObject(UserProfileStore())
        .environmentObject(TaxLedgerStore.shared)
        .environmentObject(PayslipStore())
}
