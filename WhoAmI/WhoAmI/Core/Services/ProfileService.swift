import Foundation
import Supabase

protocol ProfileService: Sendable {
    func fetch(id: UUID) async throws -> UserProfile?
    func upsert(id: UUID, displayName: String, bio: String?, igHandle: String?) async throws
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

    func upsert(id: UUID, displayName: String, bio: String?, igHandle: String?) async throws {
        struct Payload: Encodable {
            let id: String
            let display_name: String
            let bio: String?
            let age_verified: Bool   // attestation: they passed the 18+ gate to reach this screen
            let ig_handle: String?
        }
        let payload = Payload(
            id: id.uuidString,
            display_name: displayName,
            bio: bio,
            age_verified: true,
            ig_handle: igHandle
        )
        try await client.from("users").upsert(payload).execute()
    }
}
