//
//  TaxIsApp.swift
//  TaxÍs
//

import SwiftUI

@main
struct TaxIsApp: App {
    @AppStorage("taxis.themePreference") private var themePreference: ThemePreference = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(TaxIsTheme.mint)
                .preferredColorScheme(themePreference.colorScheme)
        }
    }
}
