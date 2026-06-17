import SwiftUI

/// The swipeable value-prop carousel that opens onboarding (5 slides).
struct IntroPagerView: View {
    var onContinue: () -> Void
    @State private var index = 0

    private let slides: [OnboardingSlide] = [
        .init(symbol: "pencil.slash",
              title: "Your profile, written by your friends",
              subtitle: "You don't get to write a single word of it. The people who actually know you do."),
        .init(symbol: "calendar",
              title: "One prompt. Every day. About you.",
              subtitle: "The whole app answers the same question — and your friends answer it about you."),
        .init(symbol: "lock.fill",
              title: "Answers stay blind 'til enough land",
              subtitle: "No peeking — not you, not anyone. Just a counter ticking toward the unlock."),
        .init(symbol: "sparkles",
              title: "Then it becomes your gist",
              subtitle: "An AI spins every take into one short, funny, brutally fond portrait of you."),
        .init(symbol: "lock.fill",
              title: "What they hide is the loudest part",
              subtitle: "\u{201C}\u{1F512} Sarah left a private reply.\u{201D} You'll never read it. Good luck sleeping."),
    ]

    /// Slides 0, 2, 4 lean grape (intrigue); 1, 3 lean tangerine (primary) — matching the handoff.
    private func tint(for i: Int) -> Color { i.isMultiple(of: 2) ? Theme.intrigue : Theme.primary }
    private func tintSoft(for i: Int) -> Color { i.isMultiple(of: 2) ? Theme.intrigueSoft : Theme.primarySoft }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $index) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { i, slide in
                        slideContent(slide, tint: tint(for: i), tintSoft: tintSoft(for: i))
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: Theme.Space.x7) {
                    pageDots
                    GVButton(index == slides.count - 1 ? "Get started" : "Next",
                             size: .lg,
                             full: true,
                             trailingIcon: "arrow.right") {
                        // Force the user through every slide: step forward until the
                        // last slide, only then continue out of the carousel.
                        if index < slides.count - 1 {
                            withAnimation(Theme.Motion.spring) { index += 1 }
                        } else {
                            onContinue()
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.x7)
                .padding(.top, Theme.Space.x5)
                .padding(.bottom, Theme.Space.x9)
            }
        }
    }

    // MARK: - Slide

    private func slideContent(_ slide: OnboardingSlide, tint: Color, tintSoft: Color) -> some View {
        VStack(spacing: Theme.Space.x8) {
            Spacer(minLength: 0)

            RoundedRectangle(cornerRadius: Theme.Radius.xxl, style: .continuous)
                .fill(tintSoft)
                .frame(width: 132, height: 132)
                .overlay {
                    Image(systemName: slide.symbol)
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(tint)
                }

            VStack(spacing: Theme.Space.x4) {
                Text(slide.title)
                    .font(Theme.display)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)

                Text(slide.subtitle)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer(minLength: 0)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.Space.x9)
    }

    // MARK: - Page dots

    private var pageDots: some View {
        HStack(spacing: Theme.Space.x3) {
            ForEach(slides.indices, id: \.self) { i in
                Capsule(style: .continuous)
                    .fill(i == index ? Theme.primary : Theme.borderStrong)
                    .frame(width: i == index ? 24 : 8, height: 8)
                    .onTapGesture {
                        withAnimation(Theme.Motion.spring) { index = i }
                    }
            }
        }
        .animation(Theme.Motion.spring, value: index)
    }
}
