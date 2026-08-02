import SwiftUI

/// The ten accent palettes, ported verbatim from `theme/palettes.ts`.
///
/// `primary` and `secondary` are the exact web values and must not be adjusted — they
/// are used as FILLS, where dark `onAccent` text sits on top and contrast is already
/// fine. `textOnLight` is the DEFECT #21 fix; see below.
public struct AccentPalette: Identifiable, Hashable, Sendable {
    public let key: String
    public let label: String
    public let primary: Color
    public let secondary: Color
    public let onAccent: Color
    /// DEFECT #21 — a darkened variant for TEXT and icons on the light background.
    private let textOnLightColor: Color

    public var id: String { key }

    /// The colour to draw accent TEXT in. Fills should use `primary` in both themes.
    ///
    /// DEFECT #21: in the web app the accent is used for text as well as fills, and on
    /// the light background (#F5F3EE) every one of the ten palettes fails WCAG AA — lime
    /// measures 1.23:1 against a 4.5:1 requirement, and mono 1.02:1, i.e. very nearly
    /// invisible. Each value below was computed by darkening the primary until it just
    /// clears 4.5:1; the achieved ratio is recorded beside it. On the dark background the
    /// originals already pass comfortably (4.84:1 to 18.18:1), so they are used unchanged.
    public func text(for scheme: ColorScheme) -> Color {
        scheme == .light ? textOnLightColor : primary
    }

    init(
        key: String, label: String,
        primary: UInt32, secondary: UInt32, onAccent: UInt32, textOnLight: UInt32
    ) {
        self.key = key
        self.label = label
        self.primary = Color(hex: primary)
        self.secondary = Color(hex: secondary)
        self.onAccent = Color(hex: onAccent)
        self.textOnLightColor = Color(hex: textOnLight)
    }
}

public enum Accents {
    /// Display order matters — Settings renders these as a 5×2 swatch grid.
    public static let all: [AccentPalette] = [
        //                                   primary    secondary  onAccent   textOnLight  (ratio on #F5F3EE)
        .init(key: "lime",        label: "Electric lime", primary: 0xB7EF09, secondary: 0xFF5453, onAccent: 0x0A0A09, textOnLight: 0x5C7905), // 4.52:1
        .init(key: "ember",       label: "Ember",         primary: 0xFF7C00, secondary: 0xF46EB4, onAccent: 0x0A0A09, textOnLight: 0xB15600), // 4.51:1
        .init(key: "blue",        label: "Electric blue", primary: 0x00CDFF, secondary: 0x73D25D, onAccent: 0x0A0A09, textOnLight: 0x007996), // 4.54:1
        .init(key: "blood_red",   label: "Blood red",     primary: 0xEE343B, secondary: 0xFBC600, onAccent: 0xF7F5F0, textOnLight: 0xD12E34), // 4.56:1
        .init(key: "violet",      label: "Violet",        primary: 0x9658FF, secondary: 0xFBC600, onAccent: 0xF7F5F0, textOnLight: 0x854EE3), // 4.51:1
        .init(key: "hyper_green", label: "Hyper green",   primary: 0x4DF83F, secondary: 0xFF6661, onAccent: 0x0A0A09, textOnLight: 0x288020), // 4.51:1
        .init(key: "magenta",     label: "Magenta",       primary: 0xFF2391, secondary: 0x00E2ED, onAccent: 0x0A0A09, textOnLight: 0xD21D78), // 4.52:1
        .init(key: "gold",        label: "Gold",          primary: 0xF3C530, secondary: 0xEE343B, onAccent: 0x0A0A09, textOnLight: 0x866C1A), // 4.54:1
        .init(key: "cyan",        label: "Cyan",          primary: 0x1EE6E7, secondary: 0xFF7C00, onAccent: 0x0A0A09, textOnLight: 0x107C7D), // 4.51:1
        .init(key: "mono",        label: "Mono",          primary: 0xF7F5F0, secondary: 0xA8A59A, onAccent: 0x0A0A09, textOnLight: 0x706F6D), // 4.53:1
    ]

    public static let defaultKey = "lime"

    public static func palette(for key: String) -> AccentPalette {
        all.first { $0.key == key } ?? all[0]
    }

    /// Onboarding uses a fixed lime on near-black regardless of the user's choice — the
    /// `.ob` scope in global.css. It is deliberately a different lime from the accent.
    public static let onboardingLime = Color(hex: 0xC1F038)
    public static let onboardingBackground = Color(hex: 0x0A0A09)

    /// Confetti palette from palettes.ts — lime/coral/cyan/gold/violet/magenta/green.
    public static let confetti: [Color] = [
        Color(hex: 0xC1F038), Color(hex: 0xF76E5C), Color(hex: 0x00CDFF), Color(hex: 0xF3C530),
        Color(hex: 0x9658FF), Color(hex: 0xFF2391), Color(hex: 0x55C46E),
    ]
}

/// The eight split options shown on PickSplit, in display order. The last is the
/// pseudo "Build my own" entry; the rest map to seed split ids.
public struct SplitOption: Identifiable, Hashable, Sendable {
    public let id: String
    public let badge: String?
    public init(id: String, badge: String? = nil) {
        self.id = id
        self.badge = badge
    }
}

public enum SplitOptions {
    public static let customSplitId = "custom"
    public static let all: [SplitOption] = [
        SplitOption(id: "ppl_6day", badge: "RECOMMENDED"),
        SplitOption(id: "upper_lower_4day"),
        SplitOption(id: "phul_4day"),
        SplitOption(id: "bro_5day"),
        SplitOption(id: "arnold_6day"),
        SplitOption(id: "glute_focused_5day"),
        SplitOption(id: "full_body_3day"),
        SplitOption(id: customSplitId),
    ]
}
