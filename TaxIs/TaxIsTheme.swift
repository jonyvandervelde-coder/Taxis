//
//  TaxIsTheme.swift
//  TaxÍs
//
//  Swift port of the "Trust & Mint" dark palette used by the actual
//  interactive mockup (TaxIs Mockup.dc.html, imported from Claude Design
//  2026-07-30) — matches docs/2026-07-20-design-system.md's dark Tailwind
//  tokens, NOT docs/2026-07-26-theme.md's light palette this file
//  originally used. That doc called itself "the approved interactive
//  mockup," but the actual mockup we were handed is dark — treating the
//  real interactive artifact as authoritative over the markdown claim.
//  Token *names* are kept stable from the earlier light version so no
//  call site needed to change, only these values.
//
//  Tint/border composites (mintTint, amberTint, etc.) are opacity-based
//  rather than flat hex, matching how the mockup actually builds them
//  (e.g. `background: rgba(16,185,129,.1)` over the dark card/bg color)
//  — a flat hex would have baked in a specific background to composite
//  against, which breaks depending on what the tint sits on top of.
//

import SwiftUI

enum TaxIsTheme {
    // Core
    static let bg = Color(hex: 0x0F172A)
    static let mint = Color(hex: 0x10B981)
    static let red = Color(hex: 0xEF4444)

    /// Primary heading/text color. Named `navy` for historical reasons
    /// (the light theme's navy doubled as its primary text color); on
    /// this dark palette it's the same value as `text`.
    static let navy = Color(hex: 0xF8F9FA)

    // Text & structure
    static let text = Color(hex: 0xF8F9FA)
    static let body = Color(hex: 0x94A3B8)
    static let secondary = Color(hex: 0x94A3B8)
    static let muted = Color(hex: 0x94A3B8)
    static let border = Color(hex: 0x263449)
    /// Stronger divider tone — avatar rings, chart tick marks, disabled-card borders.
    static let borderStrong = Color(hex: 0x334155)
    static let card = Color(hex: 0x1E293B)

    // Mint family
    static let mintTint = mint.opacity(0.1)
    static let mintText = mint
    /// Text-on-solid-mint (e.g. a filled mint CTA button) — dark bg color
    /// gives the strongest contrast against a bright mint fill.
    static let onMint = bg

    // Red family
    static let redText = red

    // Amber family — OCR "confirm" / low-confidence flags (not used by
    // the mockup directly; derived to match its mint/red composite pattern).
    static let amber = Color(hex: 0xF59E0B)
    static let amberTint = amber.opacity(0.1)
    static let amberBorder = amber.opacity(0.4)

    enum Radius {
        static let card: CGFloat = 16
        static let control: CGFloat = 12
        static let pill: CGFloat = 20
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
