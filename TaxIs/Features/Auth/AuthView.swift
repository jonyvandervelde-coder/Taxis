//
//  AuthView.swift
//  TaxÍs
//
//  Sign-in screen: Apple Sign In, Google OAuth, or email/password.
//  Apple and Google require the respective providers to be enabled in
//  the Supabase dashboard (Authentication → Providers).
//

import SwiftUI
import AuthenticationServices

struct AuthView: View {
    @ObservedObject var session: SessionStore
    @EnvironmentObject var profileStore: UserProfileStore

    @State private var currentNonce: String?
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var showForgotPassword = false
    @State private var forgotPasswordEmail = ""

    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 28) {
                    TaxIsLogo()
                        .frame(height: 40)
                        .padding(.top, 60)

                    // Title
                    VStack(alignment: .leading, spacing: 6) {
                        Text(isCreatingAccount ? "Búa til aðgang" : "Innskráning")
                            .font(.title2.bold())
                            .foregroundStyle(TaxIsTheme.text)
                        Text(isCreatingAccount
                             ? "Stofnaðu aðgang til að nota TaxÍs."
                             : "Skráðu þig inn til að halda áfram.")
                            .font(.subheadline)
                            .foregroundStyle(TaxIsTheme.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Social buttons
                    VStack(spacing: 10) {
                        appleSignInButton
                        googleSignInButton
                    }

                    divider

                    // Email / password form
                    VStack(spacing: 12) {
                        TextField("Netfang", text: $email)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .authField()

                        SecureField("Lykilorð", text: $password)
                            .textContentType(isCreatingAccount ? .newPassword : .password)
                            .authField()

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(TaxIsTheme.redText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let infoMessage {
                            Text(infoMessage)
                                .font(.footnote)
                                .foregroundStyle(TaxIsTheme.mint)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Forgot password (only shown on sign-in screen)
                        if !isCreatingAccount {
                            Button {
                                forgotPasswordEmail = email
                                showForgotPassword = true
                            } label: {
                                Text("Gleymdir þú lykilorðinu?")
                                    .font(.footnote)
                                    .foregroundStyle(TaxIsTheme.mintText)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }

                        Button {
                            Task { await submitEmail() }
                        } label: {
                            ZStack {
                                if isLoading {
                                    ProgressView().tint(TaxIsTheme.onMint)
                                } else {
                                    Text(isCreatingAccount ? "Stofna aðgang" : "Skrá inn")
                                        .font(.subheadline.weight(.semibold))
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                (isLoading || email.isEmpty || password.isEmpty)
                                    ? TaxIsTheme.mint.opacity(0.5)
                                    : TaxIsTheme.mint
                            )
                            .foregroundStyle(TaxIsTheme.onMint)
                            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
                        }
                        .disabled(isLoading || email.isEmpty || password.isEmpty)
                    }

                    Button {
                        isCreatingAccount.toggle()
                        errorMessage = nil
                        infoMessage = nil
                    } label: {
                        Text(isCreatingAccount
                             ? "Ertu með aðgang? Skrá inn"
                             : "Nýr notandi? Búa til aðgang")
                            .font(.footnote)
                            .foregroundStyle(TaxIsTheme.secondary)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
            }
        }
        .alert(isPresented: $showForgotPassword) {
            forgotPasswordAlert
        }
    }

    // MARK: - Apple Sign In

    private var appleSignInButton: some View {
        SignInWithAppleButton { request in
            let nonce = SupabaseAuthService.generateNonce()
            currentNonce = nonce
            request.requestedScopes = [.fullName, .email]
            request.nonce = SupabaseAuthService.sha256(nonce)
        } onCompletion: { result in
            handleAppleResult(result)
        }
        .signInWithAppleButtonStyle(.white)
        .frame(height: 50)
        .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard
                let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let token = String(data: tokenData, encoding: .utf8),
                let nonce = currentNonce
            else {
                errorMessage = "Tókst ekki að skrá inn með Apple."
                return
            }
            isLoading = true
            errorMessage = nil
            Task {
                do {
                    try await SupabaseAuthService.shared.signInWithApple(identityToken: token, nonce: nonce)
                    profileStore.email = UserDefaults.standard.string(forKey: "taxis.profile.email") ?? ""
                    session.handleSignedIn()
                } catch {
                    errorMessage = error.localizedDescription
                }
                isLoading = false
            }
        case .failure(let error):
            let asError = error as? ASAuthorizationError
            if asError?.code != .canceled {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Google

    private var googleSignInButton: some View {
        Button {
            signInWithGoogle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "globe")
                    .font(.system(size: 17, weight: .medium))
                Text("Skrá inn með Google")
                    .font(.subheadline.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(TaxIsTheme.inputBg)
            .foregroundStyle(TaxIsTheme.text)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
            )
        }
        .disabled(isLoading)
    }

    private func signInWithGoogle() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                try await SupabaseAuthService.shared.signInWithGoogle()
                profileStore.email = UserDefaults.standard.string(forKey: "taxis.profile.email") ?? ""
                session.handleSignedIn()
            } catch let err as SupabaseAuthError {
                if case .cancelled = err { /* nothing */ } else {
                    errorMessage = err.localizedDescription
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    // MARK: - Forgot password

    var forgotPasswordAlert: Alert {
        Alert(
            title: Text("Endursetja lykilorð"),
            message: Text("Sláðu inn netfangið þitt til að fá endursetningarpóst."),
            primaryButton: .default(Text("Senda")) {
                let sendEmail = forgotPasswordEmail.isEmpty ? email : forgotPasswordEmail
                guard !sendEmail.isEmpty else { return }
                isLoading = true
                errorMessage = nil
                Task {
                    do {
                        try await SupabaseAuthService.shared.resetPassword(email: sendEmail)
                        infoMessage = "Endursetningarpóstur hefur verið sendur á \(sendEmail)."
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                    isLoading = false
                }
            },
            secondaryButton: .cancel(Text("Hætta við"))
        )
    }

    // MARK: - Divider

    private var divider: some View {
        HStack {
            Rectangle().fill(TaxIsTheme.border).frame(height: 1)
            Text("eða").font(.footnote).foregroundStyle(TaxIsTheme.muted)
                .padding(.horizontal, 12)
            Rectangle().fill(TaxIsTheme.border).frame(height: 1)
        }
    }

    // MARK: - Email submit

    private func submitEmail() async {
        isLoading = true
        errorMessage = nil
        infoMessage = nil
        defer { isLoading = false }
        do {
            if isCreatingAccount {
                let signedIn = try await SupabaseAuthService.shared.signUp(email: email, password: password)
                if signedIn {
                    profileStore.email = email
                    session.handleSignedIn()
                } else {
                    infoMessage = "Staðfestingarpóstur hefur verið sendur. Staðfestu netfangið og skráðu þig inn."
                    isCreatingAccount = false
                }
            } else {
                try await SupabaseAuthService.shared.signIn(email: email, password: password)
                profileStore.email = email
                session.handleSignedIn()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private extension View {
    func authField() -> some View {
        self
            .font(.body)
            .foregroundStyle(TaxIsTheme.text)
            .padding(14)
            .background(TaxIsTheme.inputBg)
            .clipShape(RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control))
            .overlay(
                RoundedRectangle(cornerRadius: TaxIsTheme.Radius.control)
                    .strokeBorder(TaxIsTheme.borderStrong, lineWidth: 1)
            )
    }
}

#Preview {
    AuthView(session: SessionStore())
        .environmentObject(UserProfileStore())
}
