import Foundation
import Observation

@MainActor
@Observable
final class ProfileSetupViewModel {
    var displayName = ""
    var bio = ""
    var igHandle = ""
    var error: String?
    var busy = false

    private let profile: ProfileService
    private let auth: AuthService

    init(profile: ProfileService, auth: AuthService) {
        self.profile = profile
        self.auth = auth
    }

    /// Returns true on success so the caller can refresh routing.
    func save() async -> Bool {
        guard let uid = auth.currentUserID else {
            error = "Not signed in."
            return false
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            error = "Pick a display name."
            return false
        }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await profile.upsert(
                id: uid,
                displayName: name,
                bio: bio.isEmpty ? nil : bio,
                igHandle: igHandle.isEmpty ? nil : igHandle
            )
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
