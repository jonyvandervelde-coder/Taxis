//
//  ContentView.swift
//  TaxÍs
//
//  Root router with three gates in order:
//    1. TermsView — shown once, until termsAccepted is set.
//    2. AuthView  — shown until there's a Supabase session (DEBUG-skippable).
//    3. OnboardingFlowView — shown until worker-type is selected.
//    4. MainTabView — the main app experience.
//
//  The three local data stores (salariedJobStore, revenueStore,
//  expenseStore) are created here and injected as @EnvironmentObject so
//  HomeView and DeductionsView share the same live instances without
//  needing to thread them through every intermediate view.
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
    @State private var showSplash = true

    private var isDebugMode: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    var body: some View {
        ZStack {
            if !onboarding.termsAccepted {
                TermsView { onboarding.acceptTerms() }
            } else if session.isSignedIn || isDebugMode {
                if onboarding.hasCompletedOnboarding {
                    MainTabView(session: session, onboarding: onboarding)
                } else {
                    OnboardingFlowView(onboarding: onboarding)
                }
            } else {
                AuthView(session: session)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
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
