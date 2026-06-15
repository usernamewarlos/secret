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
}
