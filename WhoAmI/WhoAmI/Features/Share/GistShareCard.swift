import SwiftUI

/// The screenshot-ready share artifact (docs/PRODUCT.md §6.10). Restyled to look
/// like `GistCard` on the INK surface: a poster with the GrapeMark + "grapevine"
/// top bar, an "On: PROMPT" mono kicker, the BOLD ORANGE gist verdict, and a
/// "synthesized from your replies" footer. No grape-cluster watermark.
///
/// Kept at a fixed 360×480 frame so `ImageRenderer` output stays crisp across
/// devices. The struct name and `verdict / text / prompt` init are preserved.
struct GistShareCard: View {
    let verdict: String
    let text: String
    let prompt: String

    // One-off design constants matching GistCard's ink surface.
    private let inkTop = Color(hex: 0x241B2E)            // #241B2E
    private let inkBottom = Color(hex: 0x161019)         // #161019
    private let gistOrange = Color(hex: 0xFF7847)        // BOLD ORANGE gist text
    private let inkFg = Color(hex: 0xF7F2EE)             // cream foreground
    private var inkSub: Color { Color(hex: 0xF7F2EE, opacity: 0.62) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            topBar

            if !prompt.isEmpty {
                Text("On: \(prompt)")
                    .font(BrandFont.mono(11, .bold))
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(inkSub)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // The gist poster — huge display type in bold orange.
            VStack(alignment: .leading, spacing: 10) {
                Text(verdict)
                    .font(BrandFont.hanken(32, .black))
                    .tracking(-32 * 0.04)
                    .lineSpacing(32 * 0.04)
                    .foregroundStyle(gistOrange)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)                 // never overflow the fixed-size share card
                    .minimumScaleFactor(0.7)      // shrink gracefully if the verdict runs long
                    .fixedSize(horizontal: false, vertical: true)

                if !text.isEmpty {
                    Text(text)
                        .font(BrandFont.hanken(15, .medium))
                        .lineSpacing(3)
                        .foregroundStyle(inkFg.opacity(0.88))
                        .lineLimit(6)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .topLeading)

            footer
        }
        .padding(30)
        .frame(width: 360, height: 480, alignment: .leading)
        .background(
            LinearGradient(
                colors: [inkTop, inkBottom],
                startPoint: UnitPoint(x: 0.18, y: 0),
                endPoint: UnitPoint(x: 0.82, y: 1)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xxl, style: .continuous))
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack(spacing: 8) {
            GrapeMark(size: 22, monoColor: inkFg)
            Text("grapevine")
                .font(BrandFont.hanken(16, .black))
                .tracking(-0.48)
                .foregroundStyle(inkFg)
        }
    }

    private var footer: some View {
        Text("synthesized from your replies")
            .font(BrandFont.mono(11, .regular))
            .tracking(0.44)
            .foregroundStyle(inkSub)
            .lineLimit(1)
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    GistShareCard(
        verdict: "The chaotic glue of the group.",
        text: "Twelve friends agree: you're the one who keeps everyone laughing, the spark that turns a quiet night into a story worth retelling.",
        prompt: "What are they like in the group chat?"
    )
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
}
