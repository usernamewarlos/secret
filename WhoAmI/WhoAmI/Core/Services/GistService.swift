import Foundation
import Supabase

protocol GistService: Sendable {
    func currentVersion(postId: UUID) async throws -> GistVersion?
    func versions(postId: UUID) async throws -> [GistVersion]
}

final class LiveGistService: GistService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    private func gist(postId: UUID) async throws -> Gist? {
        let rows: [Gist] = try await client
            .from("gists").select()
            .eq("post_id", value: postId.uuidString)
            .limit(1).execute().value
        return rows.first
    }

    func currentVersion(postId: UUID) async throws -> GistVersion? {
        guard let gist = try await gist(postId: postId), let versionId = gist.currentVersionId else {
            return nil
        }
        let rows: [GistVersion] = try await client
            .from("gist_versions").select()
            .eq("id", value: versionId.uuidString)
            .limit(1).execute().value
        return rows.first
    }

    func versions(postId: UUID) async throws -> [GistVersion] {
        guard let gist = try await gist(postId: postId) else { return [] }
        return try await client
            .from("gist_versions").select()
            .eq("gist_id", value: gist.id.uuidString)
            .order("created_at", ascending: true)
            .execute().value
    }
}
