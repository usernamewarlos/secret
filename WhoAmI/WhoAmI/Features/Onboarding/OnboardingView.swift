import SwiftUI

/// Onboarding coordinator: 18+ age gate → phone verification.
/// Once verified, auth state flips and `RootView` advances to profile setup.
struct OnboardingView: View {
    @State private var passedAgeGate = false

    var body: some View {
        NavigationStack {
            if passedAgeGate {
                EmailAuthView()
            } else {
                AgeGateView(onPass: { passedAgeGate = true })
            }
        }
    }
}
