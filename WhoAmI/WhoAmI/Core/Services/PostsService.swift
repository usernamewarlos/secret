import Foundation
import Supabase

protocol PostsService: Sendable {
    func myPosts() async throws -> [Post]
    func posts(ownerId: UUID) async throws -> [Post]
    func post(ownerId: UUID, promptId: UUID) async throws -> Post?
}

final class LivePostsService: PostsService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func myPosts() async throws -> [Post] {
        guard let me = client.auth.currentUser?.id else { return [] }
        return try await posts(ownerId: me)
    }

    func posts(ownerId: UUID) async throws -> [Post] {
        try await client
            .from("posts").select()
            .eq("profile_owner_id", value: ownerId.uuidString)
            .order("created_at", ascending: false)
            .execute().value
    }

    func post(ownerId: UUID, promptId: UUID) async throws -> Post? {
        let rows: [Post] = try await client
            .from("posts").select()
            .eq("profile_owner_id", value: ownerId.uuidString)
            .eq("prompt_id", value: promptId.uuidString)
            .limit(1).execute().value
        return rows.first
    }
}
