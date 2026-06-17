import SwiftUI

// =============================================================================
// ToneTag — the color-coded label for a prompt's tone. Drives the daily deck's
// editorial rhythm: wholesome · playful · social · spicy.
//
// Mono, UPPERCASE, tracked pill. Tinted with the tone's soft background and
// solid tone color for text + icon. Leading SF Symbol stands in for the
// Phosphor tone glyph (Fill weight). Two sizes: sm / md.
//
// Mirrors the design source (ToneTag.jsx):
//   gap 6 · padding sm 3/9, md 5/12 · radius pill · mono bold ·
//   size sm = text-2xs(11) / md = text-xs(12) · letterSpacing 0.12em ·
//   uppercase · icon sm 12 / md 14.
// =============================================================================

struct ToneTag: View {
    enum Size {
        case sm, md

        var fontSize: CGFloat { self == .sm ? 11 : 12 }
        var iconSize: CGFloat { self == .sm ? 12 : 14 }
        var hPadding: CGFloat { self == .sm ? 9 : 12 }
        var vPadding: CGFloat { self == .sm ? 3 : 5 }
    }

    private let tone: Tone
    private let size: Size

    init(_ tone: Tone, size: Size = .md) {
        self.tone = tone
        self.size = size
    }

    var body: some View {
        HStack(spacing: Theme.Space.x2 + 2) { // 6pt — matches design `gap: 6`
            Image(systemName: tone.symbol)
                .font(.system(size: size.iconSize, weight: .semibold))

            Text(tone.label.uppercased())
                .font(BrandFont.mono(size.fontSize, .bold))
                .tracking(size.fontSize * 0.12) // 0.12em
                .lineSpacing(0)
        }
        .foregroundStyle(tone.color)
        .padding(.horizontal, size.hPadding)
        .padding(.vertical, size.vPadding)
        .background(tone.soft, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(tone.label) tone")
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Theme.Space.x6) {
        HStack(spacing: Theme.Space.x4) {
            ToneTag(.wholesome)
            ToneTag(.playful)
            ToneTag(.social)
            ToneTag(.spicy)
        }

        HStack(spacing: Theme.Space.x4) {
            ToneTag(.wholesome, size: .sm)
            ToneTag(.playful, size: .sm)
            ToneTag(.social, size: .sm)
            ToneTag(.spicy, size: .sm)
        }
    }
    .padding(Theme.Space.x8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
}
