//
//  TaxIsApp.swift
//  TaxÍs
//

import SwiftUI

@main
struct TaxIsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                // TaxIsTheme is dark-only (no light variant defined), so
                // force dark appearance app-wide. Without this, native
                // controls (TextField, SecureField, keyboard) fall back to
                // the system's light-mode defaults — e.g. black input text
                // — which is unreadable against our dark navy backgrounds.
                .preferredColorScheme(.dark)
                // Brand accent for every native control's tint (text
                // cursors, toggles, etc.) — one place instead of repeating
                // it per screen.
                .tint(TaxIsTheme.mint)
        }
    }
}
