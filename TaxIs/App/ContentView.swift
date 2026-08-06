//
//  ContentView.swift
//  TaxÍs
//
//  Root router with gates in order:
//    1. TermsView — shown once, until termsAccepted is set.
//    2. AuthView  — shown until there's a Supabase session.
//    3. OnboardingFlowView — shown until worker-type is selected.
//    4. MainTabView — the main app experience.
//
//  AppLockView is overlaid on top of everything whenever
//  AppLockService.isLocked == true (triggered on background → foreground).
//

import SwiftUI

struct ContentView: View {
    @StateObject private var session        = SessionStore()
    @StateObject private var onboarding     = OnboardingStore()
    @StateObject private var salariedStore  = SalariedJobStore()
    @StateObject private var revenueStore   = VerktakiRevenueStore()
    @StateObject private var expenseStore   = VerktakiExpenseStore()
    @StateObject private var profileStore   = UserProfileStore()
    @StateObject private var aksturStore    = AkstursbokStore()
    @StateObject private var lm             = LocalizationManager.shared
    @StateObject private var ledgerStore    = TaxLedgerStore.shared
    @ObservedObject private var lockService = AppLockService.shared

    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            // ── Main content ────────────────────────────────────────────
            if !onboarding.termsAccepted {
                TermsView { onboarding.acceptTerms() }
            } else if session.isSignedIn {
                if onboarding.hasCompletedOnboarding {
                    MainTabView(session: session, onboarding: onboarding)
                } else {
                    OnboardingFlowView(onboarding: onboarding)
                }
            } else {
                AuthView(session: session)
            }

            // ── App lock overlay ────────────────────────────────────────
            if lockService.isLocked {
                AppLockView(lockService: lockService)
                    .transition(.opacity)
                    .zIndex(10)
            }

            // ── Splash ──────────────────────────────────────────────────
            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(20)
            }
        }
        .environmentObject(salariedStore)
        .environmentObject(revenueStore)
        .environmentObject(expenseStore)
        .environmentObject(profileStore)
        .environmentObject(aksturStore)
        .environmentObject(lm)
        .environmentObject(ledgerStore)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.7)) {
                    showSplash = false
                }
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .background:
                lockService.lockApp()
            case .active:
                lockService.handleForeground()
            default:
                break
            }
        }
        .onOpenURL { url in
            SupabaseAuthService.shared.handleOAuthCallback(url: url)
            if (try? SupabaseSession.currentAccessToken()) != nil {
                session.handleSignedIn()
            }
        }
    }
}

#Preview {
    ContentView()
}
