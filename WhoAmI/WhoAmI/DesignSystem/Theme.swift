import SwiftUI
import UIKit

// =============================================================================
// Grapevine — Design tokens (SwiftUI port of design_system/tokens/*.css)
//
// Two brand poles: Tangerine (warmth, the daily ritual, every primary action)
// and Grape (intrigue, private replies, locks, the reveal). Warm-tinted
// neutrals (never pure grey). True dual theme — the app defaults to dark.
//
// This enum is the single source of truth every primitive + screen builds on.
// =============================================================================

enum Theme {

    // MARK: - Brand scales (raw values)

    enum Tangerine {
        static let s50  = Color(hex: 0xFFF1EC)
        static let s100 = Color(hex: 0xFFE0D4)
        static let s200 = Color(hex: 0xFFC1A8)
        static let s300 = Color(hex: 0xFF9B73)
        static let s400 = Color(hex: 0xFF7847)
        static let s500 = Color(hex: 0xFF5A2C)   // base brand
        static let s600 = Color(hex: 0xED4316)
        static let s700 = Color(hex: 0xC5320C)
        static let s800 = Color(hex: 0x9C2A0E)
        static let s900 = Color(hex: 0x7A2611)
    }

    enum Grape {
        static let s50  = Color(hex: 0xF4EEFF)
        static let s100 = Color(hex: 0xE7DBFF)
        static let s200 = Color(hex: 0xCDB4FF)
        static let s300 = Color(hex: 0xAD86FF)
        static let s400 = Color(hex: 0x9460FF)
        static let s500 = Color(hex: 0x7E3FF2)   // base intrigue
        static let s600 = Color(hex: 0x6B27D9)
        static let s700 = Color(hex: 0x561CB0)
        static let s800 = Color(hex: 0x421785)
        static let s900 = Color(hex: 0x2E0F63)
    }

    enum Ink {
        static let s0   = Color(hex: 0xFFFFFF)
        static let s50  = Color(hex: 0xFBF8F6)   // warm paper
        static let s100 = Color(hex: 0xF4EFEA)
        static let s200 = Color(hex: 0xE8E0D8)
        static let s300 = Color(hex: 0xD6CABE)
        static let s400 = Color(hex: 0xA89E94)
        static let s500 = Color(hex: 0x7C7368)
        static let s600 = Color(hex: 0x574F47)
        static let s700 = Color(hex: 0x3D3730)
        static let s800 = Color(hex: 0x2A2520)
        static let s900 = Color(hex: 0x1A1612)
        static let s950 = Color(hex: 0x100D0A)
    }

    // MARK: - Semantic colors (adapt light/dark)

    static let bg           = Color(lightHex: 0xFBF8F6, darkHex: 0x161019)
    static let bgElevated   = Color(lightHex: 0xFFFFFF, darkHex: 0x1F1726)
    static let surface      = Color(lightHex: 0xFFFFFF, darkHex: 0x1F1726)
    static let surface2     = Color(lightHex: 0xF4EFEA, darkHex: 0x2A2032)
    static let surfaceSunken = Color(lightHex: 0xF4EFEA, darkHex: 0x120D17)

    static let text         = Color(lightHex: 0x1A1612, darkHex: 0xF7F2EE)
    static let textMuted    = Color(lightHex: 0x7C7368, darkHex: 0xB3A8B0)
    static let textFaint    = Color(lightHex: 0xA89E94, darkHex: 0x7E7280)
    static let textInverse  = Color(lightHex: 0xFFFFFF, darkHex: 0x161019)

    static let border       = Color(lightHex: 0xE8E0D8, darkHex: 0xFFFFFF, darkOpacity: 0.10)
    static let borderStrong = Color(lightHex: 0xD6CABE, darkHex: 0xFFFFFF, darkOpacity: 0.18)
    static let divider      = Color(lightHex: 0xE8E0D8, darkHex: 0xFFFFFF, darkOpacity: 0.08)

    static let primary      = Tangerine.s500
    static let primaryHover = Color(lightHex: 0xED4316, darkHex: 0xFF7847)
    static let primarySoft  = Color(lightHex: 0xFFE0D4, darkHex: 0xFF5A2C, darkOpacity: 0.16)
    static let onPrimary    = Color(lightHex: 0xFFFFFF, darkHex: 0x1A0E07)

    static let intrigue     = Color(lightHex: 0x7E3FF2, darkHex: 0x9460FF)
    static let intrigueSoft = Color(lightHex: 0xE7DBFF, darkHex: 0x7E3FF2, darkOpacity: 0.20)
    static let onIntrigue   = Color(lightHex: 0xFFFFFF, darkHex: 0x160A2E)

    // Lock / private system (reads as grape everywhere)
    static let lock         = Color(lightHex: 0x7E3FF2, darkHex: 0xAD86FF)
    static let lockBg       = Color(lightHex: 0xF4EEFF, darkHex: 0x7E3FF2, darkOpacity: 0.16)
    static let lockBorder   = Color(lightHex: 0xCDB4FF, darkHex: 0xAD86FF, darkOpacity: 0.32)

    // Status
    static let success = Color(hex: 0x2FB985)
    static let warning = Color(hex: 0xFFB020)
    static let danger  = Color(hex: 0xFF3B5C)
    static let info    = Color(hex: 0x3E8BFF)

    static let ring    = Color(lightHex: 0xFF5A2C, darkHex: 0xFF7847)
    static let scrim   = Color(lightHex: 0x1A1612, darkHex: 0x000000, lightOpacity: 0.55, darkOpacity: 0.62)

    // MARK: - Spacing (8pt grid)

    enum Space {
        static let x0: CGFloat = 0
        static let x1: CGFloat = 2
        static let x2: CGFloat = 4
        static let x3: CGFloat = 8
        static let x4: CGFloat = 12
        static let x5: CGFloat = 16
        static let x6: CGFloat = 20
        static let x7: CGFloat = 24
        static let x8: CGFloat = 32
        static let x9: CGFloat = 40
        static let x10: CGFloat = 48
        static let x11: CGFloat = 56
        static let x12: CGFloat = 64
        static let x14: CGFloat = 80
        static let x16: CGFloat = 96
    }

    static let gutter: CGFloat = 16          // screen edge padding
    static let tapMin: CGFloat = 44

    // Control heights
    static let controlSm: CGFloat = 36
    static let controlMd: CGFloat = 48
    static let controlLg: CGFloat = 56

    // Avatars
    static let avatarSm: CGFloat = 32
    static let avatarMd: CGFloat = 44
    static let avatarLg: CGFloat = 64
    static let avatarXl: CGFloat = 96

    // MARK: - Radius

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let xxl: CGFloat = 36
        static let pill: CGFloat = 999
    }

    // MARK: - Motion

    enum Motion {
        static let durFast: Double = 0.12
        static let durBase: Double = 0.20
        static let durSlow: Double = 0.36
        static let durReveal: Double = 0.64

        /// cubic-bezier(.34,1.56,.64,1) — the brand's springy ease.
        static let spring = Animation.spring(response: 0.42, dampingFraction: 0.62)
        static let easeOut = Animation.easeOut(duration: durBase)
        static let reveal = Animation.spring(response: 0.55, dampingFraction: 0.7)
    }

    // MARK: - Typography roles

    static var poster: Font  { BrandFont.hanken(64, .black) }   // poster hero (scales up on big surfaces)
    static var display: Font { BrandFont.hanken(34, .heavy) }   // screen titles
    static var heading: Font { BrandFont.hanken(26, .bold) }    // section / card titles
    static var title: Font   { BrandFont.hanken(18, .semibold) } // list rows, prompt text
    static var body: Font    { BrandFont.hanken(16, .regular) }  // replies, descriptions
    static var label: Font   { BrandFont.hanken(14, .semibold) } // buttons, tags
    static var kicker: Font  { BrandFont.mono(12, .bold) }       // mono UPPERCASE labels
    static var counter: Font { BrandFont.mono(16, .bold) }       // "8 / 10"

    // MARK: - Misc brand helpers

    static let accent = Tangerine.s500
    static var brandGradient: LinearGradient {
        LinearGradient(colors: [Grape.s600, Tangerine.s500],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// =============================================================================
// Prompt-tone accents (the editorial deck)
// =============================================================================

/// The four prompt tones, carrying their own color, soft fill, label, and icon.
/// Maps from the model's `PromptTone` and from a spice-level string.
enum Tone: String, CaseIterable, Sendable, Hashable {
    case wholesome, playful, social, spicy

    var color: Color {
        switch self {
        case .wholesome: return Color(hex: 0x2FB985)
        case .playful:   return Color(hex: 0xFFB020)
        case .social:    return Color(hex: 0x3E8BFF)
        case .spicy:     return Color(hex: 0xFF3B5C)
        }
    }

    var soft: Color {
        switch self {
        case .wholesome: return Color(lightHex: 0xD7F4E9, darkHex: 0x2FB985, darkOpacity: 0.18)
        case .playful:   return Color(lightHex: 0xFFEFCC, darkHex: 0xFFB020, darkOpacity: 0.18)
        case .social:    return Color(lightHex: 0xD9E7FF, darkHex: 0x3E8BFF, darkOpacity: 0.18)
        case .spicy:     return Color(lightHex: 0xFFD7DE, darkHex: 0xFF3B5C, darkOpacity: 0.18)
        }
    }

    var label: String {
        switch self {
        case .wholesome: return "Wholesome"
        case .playful:   return "Playful"
        case .social:    return "Social"
        case .spicy:     return "Spicy"
        }
    }

    /// SF Symbol standing in for the Phosphor tone glyphs (Fill weight).
    var symbol: String {
        switch self {
        case .wholesome: return "heart.fill"
        case .playful:   return "gamecontroller.fill"
        case .social:    return "person.2.fill"
        case .spicy:     return "flame.fill"
        }
    }

    init(_ prompt: PromptTone) {
        self = Tone(rawValue: prompt.rawValue) ?? .social
    }

    /// From a `users.default_spice_level` / `posts.spice_level` string.
    init(spice: String) {
        self = Tone(rawValue: spice.lowercased()) ?? .social
    }
}

// =============================================================================
// Brand fonts — Hanken Grotesk (display + UI) and Space Mono (counters/labels).
//
// Uses the bundled custom font when present, otherwise a high-fidelity system
// fallback (rounded for Hanken, monospaced for Space Mono) so the app looks
// coherent before the TTFs are added. Bundling the real fonts is a drop-in:
// add the files + UIAppFonts and these names resolve automatically.
// =============================================================================

enum BrandFont {
    static let hasHanken: Bool = UIFont(name: "HankenGrotesk-Bold", size: 12) != nil
    static let hasSpaceMono: Bool = UIFont(name: "SpaceMono-Bold", size: 12) != nil

    static func hanken(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        guard hasHanken else { return .system(size: size, weight: weight, design: .rounded) }
        return .custom(hankenName(weight), size: size)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        guard hasSpaceMono else { return .system(size: size, weight: weight, design: .monospaced) }
        return .custom(weight >= .bold ? "SpaceMono-Bold" : "SpaceMono-Regular", size: size)
    }

    private static func hankenName(_ weight: Font.Weight) -> String {
        switch weight {
        case .black:    return "HankenGrotesk-Black"
        case .heavy:    return "HankenGrotesk-ExtraBold"
        case .bold:     return "HankenGrotesk-Bold"
        case .semibold: return "HankenGrotesk-SemiBold"
        case .medium:   return "HankenGrotesk-Medium"
        case .light, .thin, .ultraLight: return "HankenGrotesk-Light"
        default:        return "HankenGrotesk-Regular"
        }
    }
}

private extension Font.Weight {
    static func >= (lhs: Font.Weight, rhs: Font.Weight) -> Bool {
        func rank(_ w: Font.Weight) -> Int {
            switch w {
            case .ultraLight: return 0
            case .thin: return 1
            case .light: return 2
            case .regular: return 3
            case .medium: return 4
            case .semibold: return 5
            case .bold: return 6
            case .heavy: return 7
            case .black: return 8
            default: return 3
            }
        }
        return rank(lhs) >= rank(rhs)
    }
}

// =============================================================================
// Shadows & glows
// =============================================================================

struct GVShadow {
    let color: Color
    let radius: CGFloat
    let y: CGFloat
}

extension Theme {
    static var shadowSm: GVShadow { GVShadow(color: Color(lightHex: 0x2A2520, darkHex: 0x000000, lightOpacity: 0.08, darkOpacity: 0.45), radius: 5, y: 2) }
    static var shadowMd: GVShadow { GVShadow(color: Color(lightHex: 0x2A2520, darkHex: 0x000000, lightOpacity: 0.10, darkOpacity: 0.50), radius: 12, y: 6) }
    static var shadowLg: GVShadow { GVShadow(color: Color(lightHex: 0x2A2520, darkHex: 0x000000, lightOpacity: 0.14, darkOpacity: 0.58), radius: 26, y: 16) }
    static var shadowXl: GVShadow { GVShadow(color: Color(lightHex: 0x2A2520, darkHex: 0x000000, lightOpacity: 0.18, darkOpacity: 0.66), radius: 45, y: 28) }

    static var glowTangerine: GVShadow { GVShadow(color: Tangerine.s500.opacity(0.42), radius: 22, y: 10) }
    static var glowGrape: GVShadow { GVShadow(color: Grape.s500.opacity(0.46), radius: 22, y: 10) }
}

extension View {
    func gvShadow(_ s: GVShadow) -> some View {
        shadow(color: s.color, radius: s.radius, x: 0, y: s.y)
    }

    /// Mono UPPERCASE kicker label styling ("TODAY · SATURDAY", lock tags).
    func gvKicker(_ color: Color = Theme.textMuted) -> some View {
        self.font(Theme.kicker)
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// =============================================================================
// Color helpers
// =============================================================================

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }

    /// A dynamic color that resolves differently in light vs dark mode.
    init(lightHex: UInt32, darkHex: UInt32, lightOpacity: Double = 1, darkOpacity: Double = 1) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(Color(hex: darkHex, opacity: darkOpacity))
                : UIColor(Color(hex: lightHex, opacity: lightOpacity))
        })
    }
}
