//
//  TaxIsLogo.swift
//  TaxÍs
//
//  The wordmark: "Tax" in navy (the "Trust" half of the theme name),
//  "Ís" in mint (the "Mint" half) — same two-tone split used for the
//  1024x1024 app icon (see Assets.xcassets/AppIcon.appiconset), generated
//  by scripts/generate_app_icon.swift so both stay visually identical.
//
//  Uses the default (non-rounded) system font design, same as every other
//  Dynamic Type text in the app — an earlier rounded/heavy treatment made
//  the splash screen's wordmark look like a different typeface from the
//  very next screen the user sees (e.g. Home's "Sæl, Jóhanna").
//

import SwiftUI

struct TaxIsLogo: View {
    var fontSize: CGFloat = 40

    var body: some View {
        (
            Text("Tax").foregroundStyle(TaxIsTheme.navy)
            + Text("Ís").foregroundStyle(TaxIsTheme.mint)
        )
        .font(.system(size: fontSize, weight: .heavy))
    }
}

#Preview {
    TaxIsLogo(fontSize: 60)
}
