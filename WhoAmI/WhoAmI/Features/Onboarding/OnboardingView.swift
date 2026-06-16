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
                AgeGateView(onPass: { dob in
                    // Park the verified DOB so ProfileSetupView (instantiated separately by
                    // RootView once auth flips) can persist it with age_verified = true.
                    OnboardingDraft.pendingDOB = OnboardingDraft.dobString(from: dob)
                    passedAgeGate = true
                })
            }
        }
    }
}
