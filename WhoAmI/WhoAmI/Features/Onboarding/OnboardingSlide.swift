import SwiftUI

/// A single value-prop slide shown in the intro carousel (`IntroPagerView`).
///
/// Data shape is preserved exactly: `symbol` (SF Symbol name), `title`, `subtitle`.
struct OnboardingSlide: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String
}

/// A single value-prop slide rendered on the dark brand surface.
///
/// Layout matches the Grapevine "Intro carousel" handoff: a 132pt rounded-square
/// icon tile (Theme.Radius.xl) whose fill alternates between Theme.intrigueSoft and
/// Theme.primarySoft per slide, a big SF Symbol tinted intrigue/primary, a Hanken-900
/// ~34 display headline, and a 16pt muted body line.
struct OnboardingSlideView: View {
    let slide: OnboardingSlide
    /// Slide position in the carousel — drives the alternating tile/icon tint.
    /// Defaults to 0 so existing call sites that pass only `slide:` keep compiling.
    var index: Int = 0

    /// Even slides lean intrigue (grape), odd slides lean primary (tangerine),
    /// mirroring the handoff's alternating tile fills.
    private var usesIntrigue: Bool { index % 2 == 0 }
    private var tileFill: Color { usesIntrigue ? Theme.intrigueSoft : Theme.primarySoft }
    private var accent: Color { usesIntrigue ? Theme.intrigue : Theme.primary }

    var body: some View {
        VStack(spacing: Theme.Space.x8) {
            Spacer(minLength: 0)

            // Icon tile — 132pt rounded square, alternating soft fill, big SF Symbol.
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(tileFill)
                .frame(width: 132, height: 132)
                .overlay(
                    Image(systemName: slide.symbol)
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(accent)
                )

            VStack(spacing: Theme.Space.x4) {
                Text(slide.title)
                    .font(Theme.display)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(slide.subtitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 44)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        OnboardingSlideView(
            slide: .init(
                symbol: "pencil.slash",
                title: "Your profile, written by your friends",
                subtitle: "You don't get to write a single word of it. The people who actually know you do."
            ),
            index: 0
        )
    }
}
