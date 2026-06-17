import SwiftUI

// =============================================================================
// Grapevine brand mark — the "voices cluster": a 6-bead grape bunch, each bead
// one of the brand's six hues, on a tapered stem. Ported from
// design_system/assets/grapevine-mark.svg (96×96 grid).
// =============================================================================

/// The grape-cluster mark, scalable to any size. Glossy beads with a faint
/// highlight, matching the share-card / splash artwork.
struct GrapeMark: View {
    var size: CGFloat = 96
    /// When true, all beads render in a single tint (for mono/watermark use).
    var monoColor: Color? = nil

    // (cx, cy, hue) on the 96-grid; r = 11.5.
    private let beads: [(CGFloat, CGFloat, Color)] = [
        (23,   37, Color(hex: 0xFF7847)),  // tangerine
        (48,   37, Color(hex: 0xFF5A2C)),  // tangerine base
        (73,   37, Color(hex: 0xFFB020)),  // playful amber
        (35.5, 58, Color(hex: 0x9460FF)),  // grape
        (60.5, 58, Color(hex: 0x3E8BFF)),  // social blue
        (48,   79, Color(hex: 0x2FB985)),  // wholesome green
    ]

    var body: some View {
        let scale = size / 96
        let r: CGFloat = 11.5 * scale

        ZStack {
            // tapered stem / leaf
            stem(scale: scale)

            ForEach(Array(beads.enumerated()), id: \.offset) { _, b in
                bead(color: monoColor ?? b.2, radius: r)
                    .position(x: b.0 * scale, y: b.1 * scale)
            }
        }
        .frame(width: size, height: size)
    }

    private func bead(color: Color, radius: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(0.95).lighter(0.22), color, color.darker(0.18)],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: radius * 1.6
                )
            )
            .frame(width: radius * 2, height: radius * 2)
            .overlay(
                Ellipse()
                    .fill(Color.white.opacity(monoColor == nil ? 0.5 : 0))
                    .frame(width: radius * 0.8, height: radius * 0.55)
                    .blur(radius: radius * 0.18)
                    .offset(x: -radius * 0.32, y: -radius * 0.38)
            )
    }

    private func stem(scale: CGFloat) -> some View {
        Capsule()
            .fill(monoColor ?? Color(hex: 0x9A8E70))
            .frame(width: 5 * scale, height: 20 * scale)
            .rotationEffect(.degrees(28))
            .position(x: 54 * scale, y: 22 * scale)
    }
}

// =============================================================================
// Wordmark
// =============================================================================

/// "grapevine" set in the display face, optionally with the mark.
struct Wordmark: View {
    var size: CGFloat = 28
    var color: Color = Theme.text
    var withMark: Bool = false

    var body: some View {
        HStack(spacing: size * 0.28) {
            if withMark { GrapeMark(size: size * 1.1) }
            Text("grapevine")
                .font(BrandFont.hanken(size, .black))
                .tracking(-size * 0.03)
                .foregroundStyle(color)
        }
    }
}

// =============================================================================
// Brand backgrounds
// =============================================================================

/// The splash backdrop: a grape→tangerine radial glow over warm near-black.
struct BrandSplashBackground: View {
    var body: some View {
        ZStack {
            Color(hex: 0x120B1B)
            RadialGradient(
                colors: [Theme.Grape.s500.opacity(0.55), Color(hex: 0x120B1B).opacity(0)],
                center: UnitPoint(x: 0.5, y: 0.36),
                startRadius: 0, endRadius: 360
            )
            RadialGradient(
                colors: [Theme.Tangerine.s500.opacity(0.4), Color.clear],
                center: UnitPoint(x: 0.5, y: 1.05),
                startRadius: 0, endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

// =============================================================================
// Small color math used by the mark's gloss
// =============================================================================

extension Color {
    func lighter(_ amount: Double) -> Color {
        mixed(with: .white, amount: amount)
    }
    func darker(_ amount: Double) -> Color {
        mixed(with: .black, amount: amount)
    }
    private func mixed(with other: Color, amount: Double) -> Color {
        let a = max(0, min(1, amount))
        let u1 = UIColor(self), u2 = UIColor(other)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        u1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        u2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(.sRGB,
                     red: Double(r1 + (r2 - r1) * a),
                     green: Double(g1 + (g2 - g1) * a),
                     blue: Double(b1 + (b2 - b1) * a),
                     opacity: Double(a1))
    }
}
