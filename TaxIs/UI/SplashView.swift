//
//  SplashView.swift
//  TaxÍs
//
//  Launch splash: the TaxÍs wordmark holds still, then fades away smoothly
//  — no scaling/expanding. ContentView drives the actual fade-out timing
//  (it cross-fades this view out via .transition(.opacity)); this view
//  just renders the wordmark at rest.
//

import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            TaxIsTheme.bg.ignoresSafeArea()
            TaxIsLogo(fontSize: 40)
        }
    }
}

#Preview {
    SplashView()
}
