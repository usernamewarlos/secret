import SwiftUI

// =============================================================================
// GistCard — the hero. A poster-style, screenshot-ready share-card rendering
// the AI gist + the prompt it answers. Built to look great in an
// Instagram/TikTok story. Four surfaces; huge display type; the wordmark up top.
//
// Ported from design_system/components/surfaces/GistCard.jsx.
// NOTE: the grape-cluster corner watermark was removed in this design — the only
// brand mark is the small GrapeMark + "grapevine" wordmark in the top bar.
// =============================================================================

struct GistCard: View {

    // MARK: Nested types

    enum Surface {
        case ink, tangerine, grape, paper

        /// The background fill — a 160° gradient on the vivid surfaces, a flat
        /// paper tone on `.paper`. Hex values are one-off design constants.
        var background: LinearGradient {
            switch self {
            case .ink:
                return Self.gradient(0x241B2E, 0x161019)        // #241B2E → #161019 @70%
            case .tangerine:
                return Self.gradient(0xFF7847, 0xED4316)
            case .grape:
                return Self.gradient(0x9460FF, 0x561CB0)
            case .paper:
                return Self.flat(Theme.Ink.s50)
            }
        }

        /// Foreground / gist text color.
        var fg: Color {
            switch self {
            case .ink:       return Color(hex: 0xF7F2EE)
            case .tangerine: return .white
            case .grape:     return .white
            case .paper:     return Theme.Ink.s900
            }
        }

        /// Muted sub-text (kicker, footer meta).
        var sub: Color {
            switch self {
            case .ink:       return Color(hex: 0xF7F2EE, opacity: 0.62)
            case .tangerine: return Color.white.opacity(0.78)
            case .grape:     return Color.white.opacity(0.78)
            case .paper:     return Theme.Ink.s500
            }
        }

        /// Accent used for the wordmark / brand glyph on this surface.
        var accent: Color {
            switch self {
            case .ink:       return Theme.Tangerine.s400
            case .tangerine: return Color(hex: 0xFFE0D4)
            case .grape:     return Color(hex: 0xE7DBFF)
            case .paper:     return Theme.Tangerine.s600
            }
        }

        /// Single tint that reads on the surface — used for the mono GrapeMark.
        var markTint: Color { fg }

        private static func gradient(_ top: UInt32, _ bottom: UInt32) -> LinearGradient {
            // 160deg in CSS ≈ a near-vertical sweep, top-leading → bottom-trailing.
            LinearGradient(
                colors: [Color(hex: top), Color(hex: bottom)],
                startPoint: UnitPoint(x: 0.18, y: 0),
                endPoint: UnitPoint(x: 0.82, y: 1)
            )
        }

        private static func flat(_ c: Color) -> LinearGradient {
            LinearGradient(colors: [c, c], startPoint: .top, endPoint: .bottom)
        }
    }

    enum Size {
        case sm, md, lg

        /// Card padding.
        var pad: CGFloat {
            switch self {
            case .sm: return 22
            case .md: return 30
            case .lg: return 40
            }
        }

        /// Gist poster type size (--text-3xl / 5xl / 6xl = 32 / 52 / 66).
        var gist: CGFloat {
            switch self {
            case .sm: return 32
            case .md: return 52
            case .lg: return 66
            }
        }
    }

    // MARK: Props

    let gist: String
    var prompt: String? = nil
    var name: String? = nil
    var replyCount: Int? = nil
    var date: String? = nil
    var surface: Surface = .ink
    var size: Size = .md

    init(gist: String,
         prompt: String? = nil,
         name: String? = nil,
         replyCount: Int? = nil,
         date: String? = nil,
         surface: Surface = .ink,
         size: Size = .md) {
        self.gist = gist
        self.prompt = prompt
        self.name = name
        self.replyCount = replyCount
        self.date = date
        self.surface = surface
        self.size = size
    }

    // MARK: Body

    private var hasFooter: Bool {
        (name?.isEmpty == false) || replyCount != nil || (date?.isEmpty == false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar

            if let prompt, !prompt.isEmpty {
                Text("On: \(prompt)")
                    .font(BrandFont.mono(11, .bold))
                    .tracking(1.5)               // ~0.14em on 11px
                    .textCase(.uppercase)
                    .foregroundStyle(surface.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The gist poster — huge display type, balanced wrap.
            Text(gist)
                .font(BrandFont.hanken(size.gist, .black))
                .tracking(-size.gist * 0.04)     // -0.04em
                .lineSpacing(size.gist * 0.04)   // ~line-height 1.04
                .foregroundStyle(surface.fg)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(maxHeight: .infinity, alignment: .topLeading)

            if hasFooter { footer }
        }
        .padding(size.pad)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(surface.background)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xxl, style: .continuous))
        .gvShadow(Theme.shadowXl)
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 8) {
            GrapeMark(size: 22, monoColor: surface.markTint)
            Text("grapevine")
                .font(BrandFont.hanken(16, .black))
                .tracking(-0.48)                 // -0.03em on 16px
                .foregroundStyle(surface.fg)
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            if let name, !name.isEmpty {
                Text(name)
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.44)              // ~0.04em
                    .foregroundStyle(surface.fg)
            }
            if let replyCount {
                Text("· synthesized from \(replyCount) replies")
                    .font(BrandFont.mono(11, .regular))
                    .tracking(0.44)
                    .foregroundStyle(surface.sub)
            }
            if let date, !date.isEmpty {
                Spacer(minLength: 8)
                Text(date)
                    .font(BrandFont.mono(11, .regular))
                    .tracking(0.44)
                    .foregroundStyle(surface.sub)
            }
        }
        .lineLimit(1)
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            GistCard(
                gist: "The chaotic glue of the group.",
                prompt: "How are they socially?",
                name: "Maya",
                replyCount: 12,
                date: "Jun 2026",
                surface: .ink
            )

            GistCard(
                gist: "Loyal to a fault, and the first one to show up.",
                prompt: "What can you count on them for?",
                name: "Devon",
                replyCount: 8,
                date: "Jun 2026",
                surface: .tangerine,
                size: .sm
            )

            GistCard(
                gist: "A walking inside joke generator.",
                prompt: "What makes them them?",
                name: "Priya",
                replyCount: 21,
                surface: .grape,
                size: .sm
            )

            GistCard(
                gist: "Quietly the most thoughtful person you'll meet.",
                prompt: "First impression vs. reality?",
                surface: .paper,
                size: .sm
            )
        }
        .padding(20)
    }
    .background(Theme.bg)
}
