import SwiftUI

// Port of the `:root` custom properties in `get-gym-done-web/src/styles/global.css`.
//
// The web resolves theme and accent by stamping `data-theme` / `data-accent` on the root
// element and letting the cascade do the rest. The iOS equivalent is one `ThemeTokens`
// value recomputed when either preference changes and pushed into the environment at the
// root — same single source of truth, no per-view branching.

public struct ThemeTokens: Equatable, Sendable {
    public var bg: Color
    public var surface: Color
    public var surface2: Color
    public var surface3: Color
    public var line: Color
    public var fg: Color
    public var fg2: Color
    public var fg3: Color

    public var coral: Color
    public var trendUp: Color
    public var trendDown: Color

    public var accentPrimary: Color
    public var accentSecondary: Color
    public var onAccent: Color
    /// Accent colour safe to use for TEXT in the current theme. See DEFECT #21 in
    /// Palettes.swift — on the light ground the raw accent fails WCAG AA badly.
    public var accentText: Color

    /// The web caps the app frame at 480px and centres it; on iPhone this is never hit,
    /// but it is carried over for iPad and landscape.
    public static let maxContentWidth: CGFloat = 480
}

public extension ThemeTokens {

    /// Dark is the app's default and the theme every reference screenshot was shot in.
    static func dark(accent: AccentPalette) -> ThemeTokens {
        ThemeTokens(
            bg: Color(hex: 0x0A0A09),
            surface: Color(hex: 0x16140F),
            surface2: Color(hex: 0x1F1C14),
            surface3: Color(hex: 0x2A2620),
            line: Color(hex: 0x2E2B22),
            fg: Color(hex: 0xF7F5F0),
            fg2: Color(hex: 0xA8A59A),
            fg3: Color(hex: 0x696657),
            coral: Color(hex: 0xF76E5C),
            trendUp: Color(hex: 0x55C46E),
            trendDown: Color(hex: 0xF76E5C),
            accentPrimary: accent.primary,
            accentSecondary: accent.secondary,
            onAccent: accent.onAccent,
            accentText: accent.text(for: .dark)
        )
    }

    static func light(accent: AccentPalette) -> ThemeTokens {
        ThemeTokens(
            bg: Color(hex: 0xF5F3EE),
            surface: Color(hex: 0xFFFFFF),
            surface2: Color(hex: 0xEBE8E0),
            surface3: Color(hex: 0xDDD9CD),
            line: Color(hex: 0xD6D2C4),
            fg: Color(hex: 0x14130F),
            fg2: Color(hex: 0x5A564A),
            fg3: Color(hex: 0x908A78),
            // The semantic colours are theme-independent in the web app.
            coral: Color(hex: 0xF76E5C),
            trendUp: Color(hex: 0x55C46E),
            trendDown: Color(hex: 0xF76E5C),
            accentPrimary: accent.primary,
            accentSecondary: accent.secondary,
            onAccent: accent.onAccent,
            accentText: accent.text(for: .light)
        )
    }

    /// The `.ob` scope: onboarding is fixed lime-on-near-black whatever the user's theme
    /// and accent are, so first-run screenshots are identical for everyone.
    static var onboarding: ThemeTokens {
        ThemeTokens(
            bg: Color(hex: 0x0A0A09),
            surface: Color(hex: 0x16140F),
            surface2: Color(hex: 0x1F1C14),
            surface3: Color(hex: 0x2A2620),
            line: Color(hex: 0x2E2B22),
            fg: Color(hex: 0xF7F5F0),
            fg2: Color(hex: 0xA8A59A),
            fg3: Color(hex: 0x696657),
            coral: Color(hex: 0xF76E5C),
            trendUp: Color(hex: 0x55C46E),
            trendDown: Color(hex: 0xF76E5C),
            accentPrimary: Accents.onboardingLime,
            accentSecondary: Color(hex: 0xFF5453),
            onAccent: Color(hex: 0x0A0A09),
            accentText: Accents.onboardingLime
        )
    }

    static func resolve(scheme: ColorScheme, accentKey: String) -> ThemeTokens {
        let accent = Accents.palette(for: accentKey)
        return scheme == .light ? .light(accent: accent) : .dark(accent: accent)
    }
}

// MARK: - Colour helpers

public extension Color {

    /// `Color(hex: 0xB7EF09)` — sRGB, which is what the CSS values are.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    /// The SwiftUI equivalent of CSS `color-mix(in srgb, self <amount>%, other)`.
    ///
    /// Used by the consistency heatmap's four buckets and the selected split card, which
    /// blend the accent into a surface rather than using a fixed tint.
    func mixed(with other: Color, amount: Double) -> Color {
        let t = max(0, min(1, amount))
        #if canImport(UIKit)
        let a = UIColor(self)
        let b = UIColor(other)
        var ar: CGFloat = 0, ag: CGFloat = 0, ab: CGFloat = 0, aa: CGFloat = 0
        var br: CGFloat = 0, bg: CGFloat = 0, bb: CGFloat = 0, ba: CGFloat = 0
        a.getRed(&ar, green: &ag, blue: &ab, alpha: &aa)
        b.getRed(&br, green: &bg, blue: &bb, alpha: &ba)
        return Color(
            .sRGB,
            red: Double(ar) * t + Double(br) * (1 - t),
            green: Double(ag) * t + Double(bg) * (1 - t),
            blue: Double(ab) * t + Double(bb) * (1 - t),
            opacity: Double(aa) * t + Double(ba) * (1 - t)
        )
        #else
        return t > 0.5 ? self : other
        #endif
    }
}
