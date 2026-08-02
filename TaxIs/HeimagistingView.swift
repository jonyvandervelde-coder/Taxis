import SwiftUI

// MARK: - Calculation engine

struct HeimagistingCalc {
    static let nightlyLodgingTax: Double = 800
    static let cliffNights: Int          = 90
    static let cliffIncome: Double       = 2_000_000
    static let capitalTaxRate: Double    = 0.22

    let grossTotal: Double
    let nightsUsed: Int
    let cliffTriggered: Bool

    var lodgingTax: Double {
        Double(nightsUsed) * Self.nightlyLodgingTax
    }
    var capitalTaxReserve: Double? {
        guard !cliffTriggered else { return nil }
        return grossTotal * Self.capitalTaxRate
    }
    var totalSetAside: Double {
        lodgingTax + (capitalTaxReserve ?? 0)
    }
    var nightsRemaining: Int {
        max(0, Self.cliffNights - nightsUsed)
    }
    var nightsFraction: Double {
        min(Double(nightsUsed) / Double(Self.cliffNights), 1.0)
    }
    var incomeFraction: Double {
        min(grossTotal / Self.cliffIncome, 1.0)
    }
}

// MARK: - Main view

struct HeimagistingView: View {
    @EnvironmentObject private var store: TaxLedgerStore
    @State private var showAddSheet = false
    @State private var calendarMonth = Calendar.current.startOfMonth(for: Date())

    private var stays: [TaxLedgerEntry] { store.entries.filter { $0.category == .heimagisting } }
    private var calc: HeimagistingCalc {
        HeimagistingCalc(
            grossTotal: store.metrics.grossTotal,
            nightsUsed: store.metrics.nightsUsed,
            cliffTriggered: store.metrics.cliffTriggered
        )
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    pageHeader
                    cliffTrackerCard
                    taxReserveCard
                    calendarCard
                    staysSection
                }
                .padding(18)
                .padding(.top, 40)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddStaySheet(isPresented: $showAddSheet)
                .environmentObject(store)
        }
        .task { await store.load() }
        .refreshable { await store.load() }
    }

    // MARK: Page header

    private var pageHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Heimagisting")
                    .font(.title2.bold())
                    .foregroundStyle(TaxIsTheme.navy)
                Text("Ár 2026 · Gistináttaskattur 800 kr/nótt")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Button { showAddSheet = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(TaxIsTheme.mint)
            }
        }
    }

    // MARK: Cliff tracker

    private var cliffTrackerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("ÞAKMÖRK 2026")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                cliffBadge
            }

            progressRow(
                icon: "moon.stars.fill",
                label: "Nætur",
                detail: "\(calc.nightsUsed) af 90",
                remaining: "\(calc.nightsRemaining) eftir",
                fraction: calc.nightsFraction,
                warn: calc.nightsFraction >= 0.8
            )

            progressRow(
                icon: "banknote",
                label: "Tekjur",
                detail: "\(fmtShort(calc.grossTotal)) af 2M",
                remaining: "\(fmtShort(store.metrics.allowanceRemaining)) eftir",
                fraction: calc.incomeFraction,
                warn: calc.incomeFraction >= 0.8
            )

            if calc.cliffTriggered {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(TaxIsTheme.redText)
                        .font(.caption)
                    Text("Þak náð — tekjur renna inn í persónulega skattstiga.")
                        .font(.caption)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(calc.cliffTriggered ? TaxIsTheme.redText.opacity(0.5) : TaxIsTheme.border, lineWidth: 1))
    }

    private var cliffBadge: some View {
        let triggered = calc.cliffTriggered
        return Text(triggered ? "ÞAKI NÁÐ" : "Öruggt")
            .font(.caption.weight(.bold))
            .foregroundStyle(triggered ? TaxIsTheme.redText : TaxIsTheme.mint)
            .padding(.horizontal, 9).padding(.vertical, 3)
            .background((triggered ? TaxIsTheme.redText : TaxIsTheme.mint).opacity(0.1))
            .clipShape(Capsule())
    }

    private func progressRow(icon: String, label: String, detail: String, remaining: String, fraction: Double, warn: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(warn ? TaxIsTheme.redText : TaxIsTheme.mint)
                Text("\(label): \(detail)")
                    .font(.caption)
                    .foregroundStyle(TaxIsTheme.muted)
                Spacer()
                Text(remaining)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(warn ? TaxIsTheme.redText : TaxIsTheme.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5).fill(TaxIsTheme.bg)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(warn ? TaxIsTheme.redText : TaxIsTheme.mint)
                        .frame(width: geo.size.width * CGFloat(min(fraction, 1.0)))
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: Tax reserve card

    private var taxReserveCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("SKATTAÚTREIKNINGUR")
                .font(.caption.weight(.semibold))
                .foregroundStyle(TaxIsTheme.muted)
                .padding(.horizontal, 15).padding(.top, 13).padding(.bottom, 10)

            calcRow(label: "Heildartekjur", value: fmtISK(calc.grossTotal), divider: true)
            calcRow(label: "Gistináttaskattur (\(calc.nightsUsed) × 800 kr.)", value: "− \(fmtISK(calc.lodgingTax))", divider: true)

            if let reserve = calc.capitalTaxReserve {
                calcRow(label: "22% fjármagnstekjuskattur", value: "− \(fmtISK(reserve))", divider: true)
            } else {
                HStack {
                    Text("Persónulegur skattstigi")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.muted)
                    Spacer()
                    Text("Sjá Heim")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TaxIsTheme.redText)
                }
                .padding(.horizontal, 15).padding(.vertical, 10)
                Divider().background(TaxIsTheme.border)
            }

            HStack {
                Text("Leggja til hliðar")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                Text(fmtISK(calc.totalSetAside))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.mint)
            }
            .padding(.horizontal, 15).padding(.vertical, 12)
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func calcRow(label: String, value: String, divider: Bool) -> some View {
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

    // MARK: Calendar

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Button {
                    calendarMonth = Calendar.current.date(byAdding: .month, value: -1, to: calendarMonth)!
                } label: {
                    Image(systemName: "chevron.left").font(.caption.weight(.bold))
                        .foregroundStyle(TaxIsTheme.muted)
                }
                Spacer()
                Text(monthTitle(calendarMonth))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
                Spacer()
                Button {
                    calendarMonth = Calendar.current.date(byAdding: .month, value: 1, to: calendarMonth)!
                } label: {
                    Image(systemName: "chevron.right").font(.caption.weight(.bold))
                        .foregroundStyle(TaxIsTheme.muted)
                }
            }

            weekdayHeader

            monthGrid(for: calendarMonth)
        }
        .padding(14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var weekdayHeader: some View {
        let days = ["L", "Þ", "M", "M", "F", "L", "S"]
        return HStack(spacing: 0) {
            ForEach(days, id: \.self) { d in
                Text(d)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(TaxIsTheme.muted)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func monthGrid(for monthStart: Date) -> some View {
        let cal = Calendar.current
        let days = cal.daysInMonth(monthStart)
        let firstWeekday = cal.weekdayIndex(of: monthStart)
        let bookedDates = bookedDaySet

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(0 ..< firstWeekday, id: \.self) { _ in Color.clear.frame(height: 30) }
            ForEach(1 ... days, id: \.self) { day in
                let date = cal.date(bySetting: .day, value: day, of: monthStart)!
                let isBooked = bookedDates.contains(cal.startOfDay(for: date))
                let isToday  = cal.isDateInToday(date)
                Text("\(day)")
                    .font(.caption.weight(isToday ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 30)
                    .background(isBooked ? TaxIsTheme.mint.opacity(0.25) : Color.clear)
                    .foregroundStyle(isBooked ? TaxIsTheme.mint : (isToday ? TaxIsTheme.text : TaxIsTheme.muted))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(
                        isToday ? RoundedRectangle(cornerRadius: 5).strokeBorder(TaxIsTheme.mint, lineWidth: 1) : nil
                    )
            }
        }
    }

    private var bookedDaySet: Set<Date> {
        let cal = Calendar.current
        var set = Set<Date>()
        for stay in stays {
            guard
                let ci = stay.checkIn,
                let co = stay.checkOut,
                let inDate  = dateFromString(ci),
                let outDate = dateFromString(co)
            else { continue }
            var current = inDate
            while current < outDate {
                set.insert(cal.startOfDay(for: current))
                current = cal.date(byAdding: .day, value: 1, to: current)!
            }
        }
        return set
    }

    // MARK: Stays list

    private var staysSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Gistingar")
                .font(.headline)
                .foregroundStyle(TaxIsTheme.text)

            if stays.isEmpty {
                addFirstButton
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(stays.enumerated()), id: \.element.id) { idx, stay in
                        stayRow(stay, divider: idx < stays.count - 1)
                    }
                }
                .background(TaxIsTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                    .strokeBorder(TaxIsTheme.border, lineWidth: 1))
            }
        }
    }

    private func stayRow(_ entry: TaxLedgerEntry, divider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "moon.stars.fill")
                    .foregroundStyle(TaxIsTheme.mint)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stayDateLabel(entry))
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.text)
                    if let n = entry.nightsCount {
                        Text("\(n) nætur · \(fmtISK(Double(n) * HeimagistingCalc.nightlyLodgingTax)) gistináttaskattur")
                            .font(.caption)
                            .foregroundStyle(TaxIsTheme.muted)
                    }
                }
                Spacer()
                Text(fmtISK(entry.grossAmount))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TaxIsTheme.text)
            }
            .padding(.horizontal, 14).padding(.vertical, 11)
            if divider { Divider().background(TaxIsTheme.border) }
        }
    }

    private var addFirstButton: some View {
        Button { showAddSheet = true } label: {
            HStack {
                Image(systemName: "plus.circle.fill").foregroundStyle(TaxIsTheme.mint)
                Text("Skrá fyrstu gistingu")
                    .font(.subheadline).foregroundStyle(TaxIsTheme.mint)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(TaxIsTheme.card)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: Helpers

    private func stayDateLabel(_ e: TaxLedgerEntry) -> String {
        guard let ci = e.checkIn, let co = e.checkOut else { return e.dateLogged }
        return "\(ci) → \(co)"
    }

    private func monthTitle(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        f.locale = Locale(identifier: "is_IS")
        return f.string(from: d).capitalized
    }

    private func dateFromString(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: s)
    }

    private func fmtISK(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.decimalSeparator = ","
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))") kr."
    }

    private func fmtShort(_ v: Double) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", v / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0fk", v / 1_000) }
        return "\(Int(v))"
    }
}

// MARK: - Calendar helpers

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let c = dateComponents([.year, .month], from: date)
        return self.date(from: c)!
    }
    func daysInMonth(_ monthStart: Date) -> Int {
        range(of: .day, in: .month, for: monthStart)!.count
    }
    func weekdayIndex(of date: Date) -> Int {
        // Monday-first index (0 = Mon … 6 = Sun)
        let wd = component(.weekday, from: date)
        return (wd + 5) % 7
    }
}

// MARK: - Add stay sheet

struct AddStaySheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject private var store: TaxLedgerStore

    @State private var checkIn  = Date()
    @State private var checkOut = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
    @State private var gross    = ""
    @State private var note     = ""
    @State private var isSaving = false

    private var nights: Int {
        max(0, Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0)
    }
    private var grossVal: Double? {
        Double(gross.replacingOccurrences(of: ",", with: "."))
    }
    private var isValid: Bool {
        checkOut > checkIn && (grossVal ?? 0) > 0
    }
    private var lodgingTax: Double { Double(nights) * HeimagistingCalc.nightlyLodgingTax }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                sheetHeader
                ScrollView {
                    VStack(spacing: 14) {
                        datePickers
                        nightsSummary
                        grossField
                        noteField
                        if let err = store.saveError {
                            Text(err).font(.caption).foregroundStyle(TaxIsTheme.redText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                }
                saveBtn
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var sheetHeader: some View {
        HStack {
            Text("Skrá gistingu").font(.headline).foregroundStyle(TaxIsTheme.text)
            Spacer()
            Button("Hætta við") { isPresented = false }
                .font(.subheadline).foregroundStyle(TaxIsTheme.muted)
        }
        .padding(20)
    }

    private var datePickers: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Innritun").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
                    DatePicker("", selection: $checkIn, displayedComponents: .date)
                        .labelsHidden().colorScheme(.dark)
                        .onChange(of: checkIn) {
                            if checkOut <= checkIn {
                                checkOut = Calendar.current.date(byAdding: .day, value: 1, to: checkIn)!
                            }
                        }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Útritun").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
                    DatePicker("", selection: $checkOut,
                               in: Calendar.current.date(byAdding: .day, value: 1, to: checkIn)!...,
                               displayedComponents: .date)
                        .labelsHidden().colorScheme(.dark)
                }
            }
            .padding(14)
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var nightsSummary: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "moon.stars.fill").foregroundStyle(TaxIsTheme.mint)
                    Text("\(nights) nætur")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(TaxIsTheme.text)
                }
                Text("Gistináttaskattur: \(fmtISK(lodgingTax))")
                    .font(.caption).foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            if let g = grossVal, g > 0 {
                VStack(alignment: .trailing, spacing: 3) {
                    Text("22% fjárm. skattur")
                        .font(.caption).foregroundStyle(TaxIsTheme.muted)
                    Text(fmtISK(g * 0.22))
                        .font(.subheadline.weight(.semibold)).foregroundStyle(TaxIsTheme.mint)
                }
            }
        }
        .padding(14)
        .background(TaxIsTheme.mintTint)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
            .strokeBorder(TaxIsTheme.mint.opacity(0.3), lineWidth: 1))
    }

    private var grossField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Tekjur frá gistingu (ISK)").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
            TextField("t.d. 85000", text: $gross)
                .keyboardType(.decimalPad)
                .font(.body).foregroundStyle(TaxIsTheme.text)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Athugasemd (valkvætt)").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
            TextField("t.d. Airbnb, sumarleiga…", text: $note)
                .font(.body).foregroundStyle(TaxIsTheme.text)
                .padding(12)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
        }
    }

    private var saveBtn: some View {
        Button {
            guard let g = grossVal else { return }
            isSaving = true
            Task {
                await store.addStay(gross: g, checkIn: checkIn, checkOut: checkOut, note: note)
                isSaving = false
                if store.saveError == nil { isPresented = false }
            }
        } label: {
            Group {
                if isSaving { ProgressView().tint(TaxIsTheme.onMint) }
                else { Text("Vista gistingu").font(.headline).foregroundStyle(TaxIsTheme.onMint) }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(isValid ? TaxIsTheme.mint : TaxIsTheme.muted)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
        }
        .disabled(!isValid || isSaving)
        .padding(20)
    }

    private func fmtISK(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.maximumFractionDigits = 0
        return "\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))") kr."
    }
}
