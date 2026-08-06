//
//  ProfileView.swift
//  TaxÍs
//
//  Replaces the old bare-bones Settings screen. Ported from TaxIs Mockup
//  .dc.html's "Profile" state. "Tegund starfa" (employment type) is real
//  — driven by OnboardingStore — everything else here (name, email,
//  union, VAT registration, subscription) is mockup demo content: there's
//  no user-profile or billing data model in this app yet, so it's static
//  rather than fabricated-looking-real.
//

import SwiftUI
import LocalAuthentication

struct ProfileView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var onboarding: OnboardingStore
    @EnvironmentObject var profileStore: UserProfileStore
    @EnvironmentObject var lm: LocalizationManager
    @AppStorage("taxis.themePreference") private var themePreference: ThemePreference = .system

    @ObservedObject private var lockService = AppLockService.shared

    @State private var isEditingName = false
    @State private var nameInput = ""
    @State private var showDeleteConfirmation = false
    @State private var showPINSetup = false
    @State private var newPIN = ""
    @State private var confirmPIN = ""
    @State private var pinSetupStep = 0   // 0=enter, 1=confirm
    @State private var pinError = ""

    private var employmentTypeLabel: String {
        let types = onboarding.workerTypes
        if types.contains(.employee) && types.contains(.contractor) {
            return "Blönduð (hybrid)"
        } else if types.contains(.employee) && types.contains(.heimagisting) {
            return "Launþegi + Heimagisting"
        } else if types.contains(.contractor) && types.contains(.heimagisting) {
            return "Verktaki + Heimagisting"
        } else if types.contains(.employee) {
            return "Launþegi"
        } else if types.contains(.contractor) {
            return "Verktaki"
        } else if types.contains(.heimagisting) {
            return "Heimagisting"
        } else {
            return "Óskráð"
        }
    }

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Stillingar")
                        .font(.title2.bold())
                        .foregroundStyle(TaxIsTheme.navy)

                    profileCard
                    infoList
                    languagePicker
                    themePicker
                    subscriptionCard

                    sectionHeader("Lögleg gögn")
                    legalSection

                    sectionHeader("Gögn og persónuvernd")
                    dataSection

                    sectionHeader("Öryggi")
                    securitySection

                    sectionHeader("Reikningur")
                    accountActions

                    // Version number footer
                    Text("Útgáfa \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.caption2)
                        .foregroundStyle(TaxIsTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 4)
                }
                .padding(18)
                .padding(.top, 40)
                .padding(.bottom, 20)
            }
        }
        .alert("Eyða aðgangi", isPresented: $showDeleteConfirmation) {
            Button("Eyða", role: .destructive) {
                Task { await session.deleteAccount() }
            }
            Button("Hætta við", role: .cancel) {}
        } message: {
            Text("Þessi aðgerð er óafturkræf. Öllum gögnum verður eytt.")
        }
        .sheet(isPresented: $isEditingName) {
            EditNameSheet(name: $profileStore.displayName)
        }
        .sheet(isPresented: $showPINSetup) {
            pinSetupSheet
        }
    }

    private var profileCard: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(TaxIsTheme.bg)
                    .overlay(Circle().strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
                Text(profileStore.initials)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(TaxIsTheme.mint)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    nameInput = profileStore.displayName
                    isEditingName = true
                } label: {
                    HStack(spacing: 4) {
                        Text(profileStore.displayName.isEmpty ? "Bæta við nafni" : profileStore.displayName)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(profileStore.displayName.isEmpty ? TaxIsTheme.muted : TaxIsTheme.text)
                        Image(systemName: "pencil").font(.caption2).foregroundStyle(TaxIsTheme.muted)
                    }
                }
                .buttonStyle(.plain)
                if !profileStore.displayEmail.isEmpty {
                    Text(profileStore.displayEmail)
                        .font(.footnote)
                        .foregroundStyle(TaxIsTheme.muted)
                }
            }
            Spacer()
        }
        .padding(16)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private var infoList: some View {
        VStack(spacing: 0) {
            infoRow(label: "Tegund starfa", value: employmentTypeLabel, showDivider: true)
            infoRow(label: "VSK-skráð",    value: "Nei",                showDivider: false)
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func infoRow(label: String, value: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(label).font(.subheadline).foregroundStyle(TaxIsTheme.text)
                Spacer()
                Text(value).font(.subheadline.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
            }
            .padding(.horizontal, 15).padding(.vertical, 13)
            if showDivider { Divider().background(TaxIsTheme.border) }
        }
    }

    private var subscriptionCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Áskrift").font(.subheadline.weight(.bold)).foregroundStyle(TaxIsTheme.text)
                Text("Premium · ótakmörkuð skönnun").font(.footnote).foregroundStyle(TaxIsTheme.muted)
            }
            Spacer()
            Text("Virk")
                .font(.caption.weight(.bold)).foregroundStyle(TaxIsTheme.mint)
                .padding(.horizontal, 9).padding(.vertical, 4)
                .background(TaxIsTheme.mintTint).clipShape(Capsule())
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
            .strokeBorder(TaxIsTheme.mint.opacity(0.4), lineWidth: 1))
    }

    private var languagePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tungumál / Language / Idioma")
                .font(.caption.weight(.medium))
                .foregroundStyle(TaxIsTheme.muted)
                .padding(.horizontal, 2)

            HStack(spacing: 0) {
                ForEach(AppLanguage.allCases) { lang in
                    Button {
                        lm.language = lang
                    } label: {
                        VStack(spacing: 2) {
                            Text(lang.code)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(lm.language == lang ? TaxIsTheme.onMint : TaxIsTheme.text)
                            Text(lang.displayName)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(lm.language == lang ? TaxIsTheme.onMint : TaxIsTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(lm.language == lang ? TaxIsTheme.mint : Color.clear)
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

    private var themePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Útlit / Appearance")
                .font(.caption.weight(.medium))
                .foregroundStyle(TaxIsTheme.muted)
                .padding(.horizontal, 2)

            HStack(spacing: 0) {
                ForEach(ThemePreference.allCases, id: \.rawValue) { pref in
                    Button {
                        themePreference = pref
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: pref.icon)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(themePreference == pref ? TaxIsTheme.onMint : TaxIsTheme.text)
                            Text(pref.label)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(themePreference == pref ? TaxIsTheme.onMint : TaxIsTheme.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(themePreference == pref ? TaxIsTheme.mint : Color.clear)
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

    private var accountActions: some View {
        VStack(spacing: 0) {
            Button { onboarding.reset() } label: { actionRow("Breyta starfstegund", TaxIsTheme.mintText) }
            Divider().background(TaxIsTheme.border)
            Button { session.signOut() } label: { actionRow("Skrá út", TaxIsTheme.muted) }
            Divider().background(TaxIsTheme.border)
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                actionRow("Eyða aðgangi", TaxIsTheme.redText)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    // MARK: - Legal section

    private var legalSection: some View {
        VStack(spacing: 0) {
            linkRow("Notendaskilmálar",
                    url: "https://taxis.app/terms",
                    showDivider: true)
            linkRow("Persónuverndarstefna",
                    url: "https://taxis.app/privacy",
                    showDivider: true)
            linkRow("Heimildir útreikninga",
                    url: "https://www.skatturinn.is/einstaklingar/",
                    showDivider: false)
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func linkRow(_ label: String, url: String, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            Link(destination: URL(string: url)!) {
                HStack {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
            }
            if showDivider { Divider().background(TaxIsTheme.border) }
        }
    }

    // MARK: - Data section

    private var dataSection: some View {
        VStack(spacing: 0) {
            Button { exportData() } label: {
                HStack {
                    Text("Sækja mín gögn")
                        .font(.subheadline).foregroundStyle(TaxIsTheme.mintText)
                    Spacer()
                    Image(systemName: "square.and.arrow.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.mintText)
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            Divider().background(TaxIsTheme.border)
            Button(role: .destructive) { showDeleteConfirmation = true } label: {
                HStack {
                    Text("Eyða gögnum")
                        .font(.subheadline).foregroundStyle(TaxIsTheme.redText)
                    Spacer()
                    Image(systemName: "trash")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.redText)
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
            }
            .buttonStyle(.plain)
            Divider().background(TaxIsTheme.border)
            Link(destination: URL(string: "mailto:hafa-samband@taxis.app")!) {
                HStack {
                    Text("Hafa samband")
                        .font(.subheadline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Image(systemName: "envelope")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TaxIsTheme.muted)
                }
                .padding(.horizontal, 15).padding(.vertical, 13)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card).strokeBorder(TaxIsTheme.border, lineWidth: 1))
    }

    private func exportData() {
        // TODO: generate a JSON/CSV of the user's transactions and share it
        // via UIActivityViewController. Placeholder until data-export flow is built.
    }

    // MARK: - Security section (Face ID / PIN)

    private var securitySection: some View {
        VStack(spacing: 0) {
            // Lock enable/disable toggle
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Læsa forriti")
                        .font(.subheadline)
                        .foregroundStyle(TaxIsTheme.text)
                    Text(lockService.lockEnabled ? "Virkt" : "Óvirkt")
                        .font(.caption)
                        .foregroundStyle(TaxIsTheme.muted)
                }
                Spacer()
                Toggle("", isOn: Binding(
                    get: { lockService.lockEnabled },
                    set: { enabled in
                        if !enabled {
                            lockService.disableLock()
                        } else if lockService.isBiometricAvailable() {
                            lockService.enableBiometric()
                        } else {
                            showPINSetup = true
                        }
                    }
                ))
                .tint(TaxIsTheme.mint)
                .labelsHidden()
            }
            .padding(.horizontal, 15).padding(.vertical, 13)

            if lockService.lockEnabled {
                Divider().background(TaxIsTheme.border)

                // Method picker: biometric or PIN
                if lockService.isBiometricAvailable() {
                    HStack {
                        Label(lockService.biometricLabel, systemImage: lockService.biometricIcon)
                            .font(.subheadline)
                            .foregroundStyle(TaxIsTheme.text)
                        Spacer()
                        if lockService.lockMethod == "biometric" {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TaxIsTheme.mint)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { lockService.lockMethod = "biometric" }
                    .padding(.horizontal, 15).padding(.vertical, 13)

                    Divider().background(TaxIsTheme.border)
                }

                Button {
                    pinSetupStep = 0
                    newPIN = ""
                    confirmPIN = ""
                    pinError = ""
                    showPINSetup = true
                } label: {
                    HStack {
                        Label("4-stafa PIN", systemImage: "lock.fill")
                            .font(.subheadline)
                            .foregroundStyle(TaxIsTheme.text)
                        Spacer()
                        if lockService.lockMethod == "pin" {
                            Image(systemName: "checkmark")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TaxIsTheme.mint)
                        } else {
                            Text("Stilla")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TaxIsTheme.muted)
                        }
                    }
                    .padding(.horizontal, 15).padding(.vertical, 13)
                }
                .buttonStyle(.plain)
            }
        }
        .background(TaxIsTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: TaxIsTheme.Radius.card)
                .strokeBorder(TaxIsTheme.border, lineWidth: 1)
        )
    }

    // MARK: - PIN setup sheet

    private var pinSetupSheet: some View {
        NavigationStack {
            ZStack {
                TaxIsTheme.bg.ignoresSafeArea()
                VStack(spacing: 28) {
                    Text(pinSetupStep == 0 ? "Veldu 4-stafa PIN" : "Staðfestu PIN")
                        .font(.title3.bold())
                        .foregroundStyle(TaxIsTheme.text)

                    // Dot display
                    HStack(spacing: 16) {
                        let current = pinSetupStep == 0 ? newPIN : confirmPIN
                        ForEach(0..<4, id: \.self) { i in
                            Circle()
                                .fill(i < current.count ? TaxIsTheme.mint : TaxIsTheme.borderStrong)
                                .frame(width: 14, height: 14)
                                .animation(.easeInOut(duration: 0.1), value: current.count)
                        }
                    }

                    if !pinError.isEmpty {
                        Text(pinError)
                            .font(.footnote)
                            .foregroundStyle(TaxIsTheme.redText)
                    }

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                        spacing: 12
                    ) {
                        ForEach(["1","2","3","4","5","6","7","8","9","","0","⌫"], id: \.self) { key in
                            if key.isEmpty {
                                Color.clear.frame(height: 64)
                            } else {
                                Button { handlePINSetupKey(key) } label: {
                                    Text(key)
                                        .font(.title2.weight(.medium))
                                        .foregroundStyle(TaxIsTheme.text)
                                        .frame(height: 64).frame(maxWidth: .infinity)
                                        .background(TaxIsTheme.card)
                                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                                        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                                            .strokeBorder(TaxIsTheme.border, lineWidth: 1))
                                }
                            }
                        }
                    }
                }
                .padding(32)
            }
            .navigationTitle("Stilla PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hætta við") { showPINSetup = false }
                }
            }
        }
    }

    private func handlePINSetupKey(_ key: String) {
        var pin = pinSetupStep == 0 ? newPIN : confirmPIN
        pinError = ""
        if key == "⌫" {
            if !pin.isEmpty { pin.removeLast() }
        } else if pin.count < 4 {
            pin += key
        }
        if pinSetupStep == 0 {
            newPIN = pin
            if newPIN.count == 4 { pinSetupStep = 1; confirmPIN = "" }
        } else {
            confirmPIN = pin
            if confirmPIN.count == 4 {
                if confirmPIN == newPIN {
                    lockService.setPIN(newPIN)
                    showPINSetup = false
                } else {
                    pinError = "PIN-númer passa ekki. Reyndu aftur."
                    pinSetupStep = 0
                    newPIN = ""
                    confirmPIN = ""
                }
            }
        }
    }

    // MARK: - Shared helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TaxIsTheme.muted)
            .padding(.horizontal, 2)
            .padding(.top, 4)
    }

    private func actionRow(_ label: String, _ color: Color) -> some View {
        HStack {
            Text(label).font(.subheadline).foregroundStyle(color)
            Spacer()
        }
        .padding(.horizontal, 15).padding(.vertical, 13)
    }
}

// MARK: - Edit name sheet

private struct EditNameSheet: View {
    @Binding var name: String
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Breyta nafni").font(.headline).foregroundStyle(TaxIsTheme.text)
                    Spacer()
                    Button("Hætta við") { dismiss() }.font(.subheadline).foregroundStyle(TaxIsTheme.muted)
                }
                .padding(20)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nafn").font(.caption.weight(.medium)).foregroundStyle(TaxIsTheme.muted)
                    TextField("t.d. Jón Jónsson", text: $draft)
                        .textContentType(.name)
                        .font(.body).foregroundStyle(TaxIsTheme.text)
                        .padding(12)
                        .background(TaxIsTheme.inputBg)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                        .overlay(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                            .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1))
                }
                .padding(.horizontal, 20)
                Spacer()
                Button {
                    name = draft.trimmingCharacters(in: .whitespaces)
                    dismiss()
                } label: {
                    Text("Vista")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        .background(TaxIsTheme.mint).foregroundStyle(TaxIsTheme.onMint)
                        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear { draft = name }
    }
}

#Preview {
    ProfileView(session: SessionStore(), onboarding: OnboardingStore())
        .environmentObject(UserProfileStore())
        .environmentObject(LocalizationManager.shared)
}
