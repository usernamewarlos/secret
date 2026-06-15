import SwiftUI

/// Single source of navigation truth: render the right surface for the session phase.
struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        switch session.phase {
        case .loading:
            ProgressView()
        case .signedOut:
            OnboardingView()
        case .needsProfile:
            ProfileSetupView()
        case .signedIn:
            MainTabView()
        }
    }
}
