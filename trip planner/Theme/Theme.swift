//
//  Theme.swift
//  trip planner
//
//  Design tokens from README.md. The prototype specifies colors as oklch();
//  these are the nearest-sRGB hex conversions, per the handoff instruction.
//

import SwiftUI

extension Color {
    /// Hex initializer, e.g. Color(hex: "FAF8F4").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let r, g, b, a: Double
        switch cleaned.count {
        case 8:
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8) & 0xFF) / 255
            a = Double(value & 0xFF) / 255
        default:
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8) & 0xFF) / 255
            b = Double(value & 0xFF) / 255
            a = 1
        }
        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }
}

enum AppAccent: String, CaseIterable, Identifiable {
    case orange, green, blue
    var id: String { rawValue }

    var color: Color {
        switch self {
        case .orange: return Color(hex: "EA6A2E") // oklch(0.68 0.19 45)
        case .green:  return Color(hex: "2E9E6B") // oklch(0.62 0.15 150)
        case .blue:   return Color(hex: "3D7EE0") // oklch(0.6 0.16 250)
        }
    }

    var softTint: Color {
        switch self {
        case .orange: return Color(hex: "F7E9DF")
        case .green:  return Color(hex: "E1F2EA")
        case .blue:   return Color(hex: "E3EDFB")
        }
    }
}

enum Theme {
    // Surfaces & text — UIColor semantic colors auto-adapt to dark/light mode.
    static let background = Color(UIColor.systemGroupedBackground)
    static let surface = Color(UIColor.secondarySystemGroupedBackground)
    static let textPrimary = Color(UIColor.label)
    static let textMuted = Color(UIColor.secondaryLabel)
    static let textSubtle = Color(UIColor.tertiaryLabel)

    /// Fixed (non-adaptive) warm near-black — for "always dark filled" pills
    /// (e.g. the Apple Sign-In button, selected chips) that pair a hardcoded
    /// light foreground and must not collapse to it when the system flips to
    /// dark mode, unlike `textPrimary` which tracks `UIColor.label`.
    static let inkFixed = Color(hex: "241408")

    // Settlement semantics
    static let credit = Color(hex: "2E8A5E")         // positive — "menerima"
    static let debit = Color(hex: "DE5A2A")          // negative — "bayar"
    static let creditSoftBg = Color(hex: "E4F1EA")
    static let debitSoftBg = Color(hex: "FBE6DC")
    static let neutralPillBg = Color(UIColor.tertiarySystemGroupedBackground)

    // Online / offline dot
    static let offlineDot = Color(hex: "978D83")
    static let onlineDot = Color(hex: "33A46F")

    /// Avatar palette, cycled by participant index.
    static let avatarPalette: [Color] = [
        Color(hex: "F0733A"), // oklch(0.7 0.19 45)
        Color(hex: "33A46F"), // oklch(0.65 0.15 150)
        Color(hex: "4A93D6"), // oklch(0.65 0.15 240)
        Color(hex: "B75CAE"), // oklch(0.62 0.16 320)
        Color(hex: "CE5F5A"), // oklch(0.6 0.14 20)
    ]

    static func avatarColor(index: Int) -> Color {
        avatarPalette[((index % avatarPalette.count) + avatarPalette.count) % avatarPalette.count]
    }

    // Shape tokens
    static let cardRadius: CGFloat = 18
    static let pillRadius: CGFloat = 12
    static let chipRadius: CGFloat = 9
    static let sheetRadius: CGFloat = 26
}

// MARK: - Rounded font helpers

extension Font {
    static func rounded(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }
}

// MARK: - Reusable card modifier

struct CardBackground: ViewModifier {
    var radius: CGFloat = Theme.cardRadius
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

extension View {
    func cardStyle(radius: CGFloat = Theme.cardRadius) -> some View {
        modifier(CardBackground(radius: radius))
    }
}
