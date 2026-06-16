import Foundation
import Observation

@MainActor
@Observable
final class ProfileSetupViewModel {
    /// Selectable default reply spice. Raw value is the `wholesome|playful|social|spicy`
    /// string the backend expects (`users.default_spice_level`).
    enum SpiceLevel: String, CaseIterable, Identifiable {
        case wholesome
        case playful
        case social
        case spicy

        var id: String { rawValue }
        var label: String {
            switch self {
            case .wholesome: return "Wholesome"
            case .playful: return "Playful"
            case .social: return "Social"
            case .spicy: return "Spicy"
            }
        }
    }

    var displayName = ""
    var bio = ""
    var igHandle = ""
    var defaultSpice: SpiceLevel = .social
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
                igHandle: igHandle.isEmpty ? nil : igHandle,
                // DOB captured at the age gate (parked across the auth-state flip); the gate
                // pass is what `age_verified = true` attests to.
                dob: OnboardingDraft.pendingDOB,
                ageVerified: true
            )
            try await profile.setDefaultSpice(level: defaultSpice.rawValue)
            OnboardingDraft.clear()
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
