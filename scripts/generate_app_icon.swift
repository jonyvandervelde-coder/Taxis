//
//  generate_app_icon.swift
//  TaxÍs
//
//  Renders the 1024x1024 App Store icon: "Tax" (navy) + "Ís" (mint) on the
//  theme's off-white background, matching TaxIsLogo.swift exactly. Run
//  with `swift generate_app_icon.swift <output.png>` — no external image
//  tools needed, just AppKit (part of the macOS system frameworks).
//
//  Apple fills/rounds the icon corners itself — this must be a flat
//  opaque square with no transparency and no pre-applied corner radius.
//

import AppKit

guard CommandLine.arguments.count > 1 else {
    print("Usage: swift generate_app_icon.swift <output.png>")
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let canvasSize = CGSize(width: 1024, height: 1024)
let image = NSImage(size: canvasSize)
image.lockFocus()

// TaxIsTheme.bg (#F8F9FA)
NSColor(srgbRed: 0xF8 / 255.0, green: 0xF9 / 255.0, blue: 0xFA / 255.0, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

// Default (non-rounded) system font design, matching TaxIsLogo.swift —
// keeps the icon visually identical to the in-app wordmark.
let fontSize: CGFloat = 300
let font = NSFont.systemFont(ofSize: fontSize, weight: .heavy)

// TaxIsTheme.navy (#1E293B)
let navy = NSColor(srgbRed: 0x1E / 255.0, green: 0x29 / 255.0, blue: 0x3B / 255.0, alpha: 1)
// TaxIsTheme.mint (#10B981)
let mint = NSColor(srgbRed: 0x10 / 255.0, green: 0xB9 / 255.0, blue: 0x81 / 255.0, alpha: 1)

let wordmark = NSMutableAttributedString()
wordmark.append(NSAttributedString(string: "Tax", attributes: [.font: font, .foregroundColor: navy]))
wordmark.append(NSAttributedString(string: "Ís", attributes: [.font: font, .foregroundColor: mint]))

let textSize = wordmark.size()
let origin = CGPoint(x: (canvasSize.width - textSize.width) / 2, y: (canvasSize.height - textSize.height) / 2)
wordmark.draw(at: origin)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    print("Failed to render PNG")
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
