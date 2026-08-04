//
//  SessionStore.swift
//  TaxÍs
//
//  Drives whether ContentView shows AuthView or the signed-in app.
//  Deliberately thin — SupabaseSession's Keychain entry stays the single
//  source of truth for the actual token; this just mirrors "is there one
//  right now" for SwiftUI to observe.
//

import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var isSignedIn: Bool
    @Published private(set) var isDeletingAccount = false

    init() {
        isSignedIn = (try? SupabaseSession.currentAccessToken()) != nil
    }

    func handleSignedIn() {
        isSignedIn = true
    }

    func signOut() {
        try? SupabaseSession.clear()
        isSignedIn = false
    }

    func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await SupabaseAuthService.shared.deleteAccount()
        } catch {
            // Clear local session even if the network call fails so the
            // user is not stuck in a signed-in state.
        }
        signOut()
    }
}
