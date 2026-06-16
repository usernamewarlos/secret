import Foundation
import Supabase

protocol ProfileService: Sendable {
    func fetch(id: UUID) async throws -> UserProfile?
    func fetchMany(ids: [UUID]) async throws -> [UserProfile]
    func upsert(
        id: UUID,
        displayName: String,
        bio: String?,
        igHandle: String?,
        dob: String?,
        ageVerified: Bool
    ) async throws
    /// Updates `users.default_spice_level` for the current user (onboarding/settings).
    func setDefaultSpice(level: String) async throws
}

final class LiveProfileService: ProfileService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func fetch(id: UUID) async throws -> UserProfile? {
        let rows: [UserProfile] = try await client
            .from("users")
            .select()
            .eq("id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func fetchMany(ids: [UUID]) async throws -> [UserProfile] {
        guard !ids.isEmpty else { return [] }
        return try await client
            .from("users")
            .select()
            .in("id", values: ids.map(\.uuidString))
            .execute()
            .value
    }

    func upsert(
        id: UUID,
        displayName: String,
        bio: String?,
        igHandle: String?,
        dob: String?,
        ageVerified: Bool
    ) async throws {
        struct Payload: Encodable {
            let id: String
            let display_name: String
            let bio: String?
            let dob: String?
            let age_verified: Bool   // attestation: they passed the 18+ gate to reach this screen
            let ig_handle: String?
        }
        let payload = Payload(
            id: id.uuidString,
            display_name: displayName,
            bio: bio,
            dob: dob,
            age_verified: ageVerified,
            ig_handle: igHandle
        )
        try await client.from("users").upsert(payload).execute()
    }

    func setDefaultSpice(level: String) async throws {
        guard let me = client.auth.currentUser?.id else {
            throw ProfileServiceError.notAuthenticated
        }
        struct Payload: Encodable { let default_spice_level: String }
        try await client
            .from("users")
            .update(Payload(default_spice_level: level))
            .eq("id", value: me.uuidString)
            .execute()
    }
}

enum ProfileServiceError: Error {
    case notAuthenticated
}
