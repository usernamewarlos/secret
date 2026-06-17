import Foundation
import Observation

/// Drives top-level routing from auth + profile state. Subscribes to auth changes and
/// recomputes `phase`; `RootView` switches on it.
@MainActor
@Observable
final class SessionStore {
    private let auth: AuthService
    private let profile: ProfileService

    private(set) var phase: AuthPhase = .loading

    init(auth: AuthService, profile: ProfileService) {
        self.auth = auth
        self.profile = profile
    }

    func start() {
        Task { await refresh() }
        Task {
            for await _ in auth.authChanges() {
                await refresh()
            }
        }
    }

    func refresh() async {
        guard let uid = auth.currentUserID else {
            phase = .signedOut
            return
        }
        do {
            let me = try await profile.fetch(id: uid)
            let hasName = (me?.displayName?.isEmpty == false)
            phase = hasName ? .signedIn : .needsProfile
        } catch {
            phase = .needsProfile
        }
    }

    func signOut() async {
        try? await auth.signOut()
        await refresh()
    }

    /// Hard-delete the account (cascades all data), then clear the local session.
    func deleteAccount() async throws {
        try await auth.deleteAccount()
        try? await auth.signOut()
        await refresh()
    }

    #if DEBUG
    /// Dev-only: when true, RootView replays the ENTIRE onboarding flow (intro →
    /// age → notifications → profile setup → invite gate), independent of auth, so
    /// it can be re-walked without creating a fresh account.
    private(set) var debugReplayOnboarding = false

    /// Start a full onboarding replay (Settings → "Reset onboarding").
    func debugRestartOnboarding() {
        OnboardingDraft.clear()
        debugReplayOnboarding = true
    }

    /// End the replay (invite gate completed) and return to normal routing.
    func endDebugReplay() {
        debugReplayOnboarding = false
    }
    #endif
}
