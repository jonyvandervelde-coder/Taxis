//
//  OnboardingFlowView.swift
//  TaxÍs
//
//  Onboarding asks exactly one question — launþegi, verktaki, or both —
//  then goes straight to MainTabView. It no longer collects payslips or
//  income up front: the user fetches that information themselves from the
//  Skanna tab (payslips, any time) and the Frádrættir tab (verktaki
//  expenses, any time), and the app computes the rest from whatever's
//  there. MainTabView shows a different tab set depending on the answer
//  given here (see its `showsDeductions`).
//

import SwiftUI

struct OnboardingFlowView: View {
    @ObservedObject var onboarding: OnboardingStore

    var body: some View {
        NavigationStack {
            WorkerTypeSelectionView(onboarding: onboarding) {
                onboarding.completeOnboarding()
            }
        }
    }
}

#Preview {
    OnboardingFlowView(onboarding: OnboardingStore())
}
