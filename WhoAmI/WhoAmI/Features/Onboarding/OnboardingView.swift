import SwiftUI

/// The signed-out onboarding flow:
/// value-prop carousel (5 slides) → 18+ age gate → notifications ask → sign-in.
/// Sign-in is last; once it succeeds, auth flips and `RootView` advances to profile setup.
struct OnboardingView: View {
    private enum Step { case intro, ageGate, notifications, signIn }
    @State private var step: Step = .intro

    var body: some View {
        ZStack {
            switch step {
            case .intro:
                IntroPagerView(onContinue: { advance(.ageGate) })
                    .transition(.opacity)
            case .ageGate:
                AgeGateView(onPass: { dob in
                    OnboardingDraft.pendingDOB = OnboardingDraft.dobString(from: dob)
                    advance(.notifications)
                })
                .transition(.opacity)
            case .notifications:
                NotificationsPromptView(onContinue: { advance(.signIn) })
                    .transition(.opacity)
            case .signIn:
                EmailAuthView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func advance(_ to: Step) {
        step = to
    }
}
