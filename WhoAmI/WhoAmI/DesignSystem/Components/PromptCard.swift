import SwiftUI

// =============================================================================
// PromptCard — the day's prompt. The hero of the Today screen and a header in
// profile archives. A tone-tinted 6px top edge, a mono kicker, the big balanced
// prompt headline, an optional "Spicy · opt-in required" notice, and an optional
// footer slot (a GVCounter, a CTA, a "waiting on you" nudge) passed as children.
//
// Port of design_system/components/surfaces/PromptCard.jsx. Consumes ToneTag.
// =============================================================================

struct PromptCard<Footer: View>: View {

    private let prompt: String
    private let tone: Tone
    private let kicker: String
    private let spicy: Bool
    private let footer: Footer

    init(
        prompt: String,
        tone: Tone,
        kicker: String = "Today",
        spicy: Bool = false,
        @ViewBuilder footer: () -> Footer = { EmptyView() }
    ) {
        self.prompt = prompt
        self.tone = tone
        self.kicker = kicker
        self.spicy = spicy
        self.footer = footer()
    }

    var body: some View {
        VStack(spacing: 0) {

            // Tone-tinted top edge (6px).
            tone.color
                .frame(height: 6)

            VStack(alignment: .leading, spacing: 0) {

                // Kicker row: mono label on the left, ToneTag pushed trailing.
                HStack(spacing: 10) {
                    Text(kicker)
                        .gvKicker(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    ToneTag(tone, size: .sm)
                }
                .padding(.bottom, 16)

                // The prompt — big, heavy, tightly tracked, balanced wrap.
                Text(prompt)
                    .font(BrandFont.hanken(30, .heavy))
                    .tracking(-0.75)               // ~-0.025em at 30pt
                    .lineSpacing(30 * 0.08)        // line-height 1.08
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)

                // Spicy opt-in notice.
                if spicy {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text("Spicy · opt-in required")
                            .font(BrandFont.mono(11, .bold))
                            .tracking(1.1)         // ~0.1em
                            .textCase(.uppercase)
                    }
                    .foregroundStyle(Tone.spicy.color)
                    .padding(.top, 14)
                }

                // Footer slot — counter, CTA, nudge.
                if Footer.self != EmptyView.self {
                    footer
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(Theme.Space.x6)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
        .gvShadow(Theme.shadowMd)
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    ScrollView {
        VStack(spacing: Theme.Space.x6) {

            PromptCard(
                prompt: "How are they socially?",
                tone: .social,
                kicker: "Today · Saturday"
            ) {
                GVCounter(count: 8, threshold: 10)
            }

            PromptCard(
                prompt: "What's the most reckless thing you'd do with them?",
                tone: .spicy,
                kicker: "Today",
                spicy: true
            ) {
                GVButton("Add your take", variant: .primary, size: .md, full: true) {}
            }

            PromptCard(
                prompt: "What small thing makes them feel instantly at home?",
                tone: .wholesome,
                kicker: "Archive · May 2"
            )
        }
        .padding(Theme.gutter)
    }
    .background(Theme.bg)
}
