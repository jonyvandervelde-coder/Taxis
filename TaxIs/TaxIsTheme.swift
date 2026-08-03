//
//  TaxIsTheme.swift
//  TaxÍs
//
//  "Trust & Mint" design system — dark palette was authoritative (see
//  comment history); light palette added 2026-08-03 so the app responds to
//  the user's system preference. Accent and semantic colours (mint, red,
//  amber, onMint) are the same hex in both modes; neutral scale inverts.
//
//  All adaptive tokens use UIColor's dynamic-provider init so SwiftUI Color
//  picks up trait-collection changes without @Environment(\.colorScheme)
//  at every call site.
//

import SwiftUI
import UIKit

enum TaxIsTheme {
    // MARK: - Adaptive helpers

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }

    private static func adaptiveAlpha(
        lightHex: UInt32, lightAlpha: CGFloat,
        darkHex:  UInt32,  darkAlpha: CGFloat
    ) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: darkHex).withAlphaComponent(darkAlpha)
                : UIColor(hex: lightHex).withAlphaComponent(lightAlpha)
        })
    }

    // MARK: - Core surfaces
    //   Light: slate-50 / white     Dark: slate-900 / slate-800

    static let bg   = adaptive(light: 0xF8FAFC, dark: 0x0F172A)
    static let card = adaptive(light: 0xFFFFFF, dark: 0x1E293B)

    /// Subtle fill for text-fields and inner-card surfaces.
    /// Light: slate-100 (#F1F5F9)  Dark: white @ 6 %
    static let inputBg = adaptiveAlpha(
        lightHex: 0xF1F5F9, lightAlpha: 1.0,
        darkHex:  0xFFFFFF, darkAlpha:  0.06
    )

    // MARK: - Brand accent (same hex in both modes)

    static let mint = Color(hex: 0x10B981)
    static let red  = Color(hex: 0xEF4444)

    // MARK: - Text
    //   Light: slate-900 / slate-500    Dark: near-white / slate-400

    /// Primary heading colour. Historical name "navy" kept for stability.
    static let navy      = adaptive(light: 0x0F172A, dark: 0xF8F9FA)
    static let text      = adaptive(light: 0x0F172A, dark: 0xF8F9FA)
    static let body      = adaptive(light: 0x64748B, dark: 0x94A3B8)
    static let secondary = adaptive(light: 0x64748B, dark: 0x94A3B8)
    static let muted     = adaptive(light: 0x64748B, dark: 0x94A3B8)

    // MARK: - Borders / dividers
    //   Light: slate-200 / slate-300    Dark: slate-700/8

    static let border       = adaptive(light: 0xE2E8F0, dark: 0x263449)
    static let borderStrong = adaptive(light: 0xCBD5E1, dark: 0x334155)

    // MARK: - Mint family

    static let mintTint  = mint.opacity(0.1)
    static let mintText  = mint
    /// Text on a solid-mint fill — slate-900 gives ~4.5 : 1 contrast against
    /// #10B981 in both modes; keep this constant, not tied to `bg`.
    static let onMint = Color(hex: 0x0F172A)

    // MARK: - Red family

    static let redText = red

    // MARK: - Amber family

    static let amber       = Color(hex: 0xF59E0B)
    static let amberTint   = amber.opacity(0.1)
    static let amberBorder = amber.opacity(0.4)

    // MARK: - Radii

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let pill: CGFloat = 20
    }
}

// MARK: - Theme preference

enum ThemePreference: String, CaseIterable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var label: String {
        switch self {
        case .system: return "Kerfi"
        case .light:  return "Ljóst"
        case .dark:   return "Myrkur"
        }
    }

    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Color init helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red:   CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8)  & 0xFF) / 255,
            blue:  CGFloat( hex        & 0xFF) / 255,
            alpha: 1
        )
    }
}
