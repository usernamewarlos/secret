import SwiftUI

/// Single source of navigation truth: a branded splash first, then the right surface for
/// the session phase.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @State private var showSplash = true

    var body: some View {
        ZStack {
            if showSplash {
                SplashView(onFinished: { showSplash = false })
                    .transition(.opacity)
            } else {
                content
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .preferredColorScheme(.dark)   // Grapevine defaults to dark (design default)
        #if DEBUG
        // A dev "Reset onboarding" truly restarts: replay the splash, then the full flow.
        .onChange(of: session.debugReplayOnboarding) { _, replaying in
            if replaying { showSplash = true }
        }
        #endif
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        if session.debugReplayOnboarding {
            DebugOnboardingReplay(onFinish: { session.endDebugReplay() })
        } else {
            routedContent
        }
        #else
        routedContent
        #endif
    }

    @ViewBuilder
    private var routedContent: some View {
        switch session.phase {
        case .loading:
            ZStack {
                Theme.bg.ignoresSafeArea()
                ProgressView().tint(Theme.primary)
            }
        case .signedOut:
            OnboardingView()
        case .needsProfile:
            OnboardingProfileFlow()
        case .signedIn:
            MainTabView()
        }
    }
}

/// The post-sign-in onboarding flow: set up your profile, then the mandatory
/// invite gate (≥5 friends, no skip). Only after the gate do we refresh the
/// session into the tab shell.
private struct OnboardingProfileFlow: View {
    @Environment(AppContainer.self) private var container
    @State private var stage: Stage = .phone

    private enum Stage { case phone, profile, invite }

    var body: some View {
        ZStack {
            switch stage {
            case .phone:
                PhoneVerifyView(onComplete: { stage = .profile }, allowSkip: true)
                    .transition(.opacity)
            case .profile:
                ProfileSetupView(onDone: { stage = .invite })
                    .transition(.opacity)
            case .invite:
                InviteFriendsView(onComplete: {
                    Task { await container.session.refresh() }
                })
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: stage)
    }
}

#if DEBUG
/// Dev-only: replays the ENTIRE onboarding flow end-to-end — intro carousel → age
/// gate → notifications → sign-in → profile setup → invite gate — without creating
/// a fresh account. Sign-in is shown for parity but can't really re-auth mid-replay
/// (you're already signed in), so it offers a "Skip sign-in (dev)" advance.
/// Triggered from Settings → "Reset onboarding".
private struct DebugOnboardingReplay: View {
    var onFinish: () -> Void
    @State private var step: Step = .intro

    private enum Step { case intro, age, notifications, signIn, phone, profile, invite }

    var body: some View {
        ZStack {
            switch step {
            case .intro:
                IntroPagerView(onContinue: { step = .age })
            case .age:
                AgeGateView(onPass: { _ in step = .notifications })
            case .notifications:
                NotificationsPromptView(onContinue: { step = .signIn })
            case .signIn:
                EmailAuthView(onReplayContinue: { step = .phone })
            case .phone:
                PhoneVerifyView(onComplete: { step = .profile }, allowSkip: true)
            case .profile:
                ProfileSetupView(onDone: { step = .invite })
            case .invite:
                InviteFriendsView(onComplete: onFinish)
            }
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.35), value: step)
    }
}
#endif
