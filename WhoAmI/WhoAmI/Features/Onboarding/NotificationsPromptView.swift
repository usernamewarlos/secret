import SwiftUI

/// Contextual notifications ask, shown in onboarding right before sign-in (replaces the
/// old launch-time prompt so the system dialog appears with context, not on cold start).
struct NotificationsPromptView: View {
    @Environment(AppContainer.self) private var container
    var onContinue: () -> Void
    @State private var busy = false

    var body: some View {
        ZStack {
            // Dark brand surface with a grape glow falling from the top.
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.Grape.s500.opacity(0.40), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: Theme.Space.x6)

                VStack(spacing: Theme.Space.x8) {
                    // Grape icon tile with grape glow.
                    ZStack {
                        RoundedRectangle(cornerRadius: 34, style: .continuous)
                            .fill(Theme.intrigue)
                        Image(systemName: "bell.badge.fill")
                            .font(.system(size: 52, weight: .semibold))
                            .foregroundStyle(Theme.onIntrigue)
                    }
                    .frame(width: 116, height: 116)
                    .gvShadow(Theme.glowGrape)

                    // Heading + supporting copy.
                    VStack(spacing: Theme.Space.x3) {
                        Text("Don't miss the moment your gist drops")
                            .font(Theme.display)
                            .foregroundStyle(Theme.text)
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)

                        Text("The big one is graduation — when enough friends answer and your gist unlocks. You'll want that ping.")
                            .font(Theme.body)
                            .foregroundStyle(Theme.textMuted)
                            .multilineTextAlignment(.center)
                            .lineSpacing(3)
                    }

                    // Sample notification preview.
                    GVCard(elevation: .mid, padding: Theme.Space.x4) {
                        HStack(spacing: Theme.Space.x3) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Theme.intrigueSoft)
                                Image(systemName: "lock.open.fill")
                                    .font(.system(size: 19, weight: .semibold))
                                    .foregroundStyle(Theme.intrigue)
                            }
                            .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("Your \u{201C}Roast them\u{201D} is ready 👀")
                                    .font(Theme.label)
                                    .fontWeight(.bold)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Text("GRAPEVINE · NOW")
                                    .gvKicker(Theme.textFaint)
                            }
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.x7)

                Spacer(minLength: Theme.Space.x6)

                // Actions.
                VStack(spacing: Theme.Space.x3) {
                    GVButton(
                        "Turn on notifications",
                        variant: .intrigue,
                        size: .lg,
                        full: true,
                        icon: "bell.fill",
                        loading: busy,
                        enabled: !busy
                    ) {
                        Task {
                            busy = true
                            await container.notifications.requestAuthorization()
                            onContinue()
                        }
                    }

                    GVButton("Maybe later", variant: .ghost, full: true, enabled: !busy) {
                        onContinue()
                    }
                }
                .padding(.horizontal, Theme.Space.x7)
                .padding(.bottom, Theme.Space.x8)
            }
        }
    }
}
