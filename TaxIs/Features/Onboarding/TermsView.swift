//
//  TermsView.swift
//  TaxÍs
//
//  Shown once at first launch (gated in ContentView before onboarding).
//  Presents the legal disclaimer and privacy policy, then calls onAccept()
//  which sets termsAccepted in OnboardingStore. Per the spec: legal text
//  appears once here only — individual screens carry no repeated disclaimers.
//

import SwiftUI

struct TermsView: View {
    let onAccept: () -> Void

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    TaxIsLogo(fontSize: 32)
                    Text("Skilmálar og persónuvernd")
                        .font(.title3.bold())
                        .foregroundStyle(TaxIsTheme.text)
                    Text("Lestu þetta áður en þú heldur áfram.")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        termSection(
                            icon: "calculator.fill",
                            title: "Reiknivél — ekki skattráðgjöf",
                            body: "TaxÍs er sjálfvirk skattareiknivél. Útreikningar eru byggðir á opinberum reglum Skatturinn og eru aðeins til viðmiðunar — þeir koma ekki í stað löggilts skattaráðgjafa."
                        )
                        termSection(
                            icon: "lock.shield.fill",
                            title: "Engar persónulegar kennitölur",
                            body: "TaxÍs geymir aldrei persónukennitölu þína, heimilisfang né bankareikningsnúmer. Þegar launaseðill er skannaður eru aðeins fjárhagstölur dregnar út — nöfn og auðkenni eru aldrei vistuð."
                        )
                        termSection(
                            icon: "iphone",
                            title: "Gögn á þínu tæki",
                            body: "Launaupplýsingar og útgjöld sem þú skráir eru geymd staðbundið á tækinu þínu. Supabase-samstilling dulkóðar gögn í flutningi ef hún er virk."
                        )
                        termSection(
                            icon: "person.fill.checkmark",
                            title: "Þitt ábyrgðarsvið",
                            body: "Endanlegar skattyfirlýsingar og greiðslur til Skatturinn eru á þinni eigin ábyrgð. TaxÍs er hjálpartæki — staðfesting hjá Skatturinn ræður alltaf."
                        )
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }

                VStack(spacing: 10) {
                    Button(action: onAccept) {
                        Text("Samþykkja og hefja")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(TaxIsTheme.mint)
                            .foregroundStyle(TaxIsTheme.onMint)
                            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                    }
                    Text("Með því að halda áfram samþykkir þú skilmálana.")
                        .font(.caption)
                        .foregroundStyle(TaxIsTheme.muted)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
                .background(TaxIsTheme.bg)
            }
        }
    }

    private func termSection(icon: String, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TaxIsTheme.mint)
                .frame(width: 30, alignment: .center)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(TaxIsTheme.text)
                Text(body)
                    .font(.subheadline)
                    .foregroundStyle(TaxIsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    TermsView(onAccept: {})
}
