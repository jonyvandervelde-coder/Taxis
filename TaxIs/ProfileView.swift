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

struct ProfileView: View {
    @ObservedObject var session: SessionStore
    @ObservedObject var onboarding: OnboardingStore
    @EnvironmentObject var profileStore: UserProfileStore
    @EnvironmentObject var lm: LocalizationManager

    @State private var isEditingName = false
    @State private var nameInput = ""
    @State private var showDeleteConfirmation = false

    private var employmentTypeLabel: String {
        let types = onboarding.workerTypes
        if types.contains(.employee) && types.contains(.contractor) {
            return "Blönduð (hybrid)"
        } else if types.contains(.employee) {
            return "Launþegi"
        } else if types.contains(.contractor) {
            return "Verktaki"
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
                    subscriptionCard
                    accountActions
                }
                .padding(18)
                .padding(.top, 40)
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
                        .background(Color.white.opacity(0.06))
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
