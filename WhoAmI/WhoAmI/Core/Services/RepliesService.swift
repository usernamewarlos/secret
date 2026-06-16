import Foundation
import Supabase

protocol RepliesService: Sendable {
    func submit(ownerId: UUID, promptId: UUID, body: String, isPrivate: Bool) async throws
    /// Owner opens a prompt on their own profile at a chosen level (capped at the prompt's tone).
    /// Use this to let a `social` owner opt into a `spicy` prompt, or to dial any prompt down.
    func openPost(ownerId: UUID, promptId: UUID, level: String) async throws
    /// Owner adjusts an already-open post's level (capped at the prompt's tone).
    func setPostSpice(postId: UUID, level: String) async throws
    /// Public, graduated replies (or the caller's own) — RLS enforces this.
    func publicReplies(postId: UUID) async throws -> [Reply]
    func myReply(postId: UUID) async throws -> Reply?
    func privateMarkers(postId: UUID) async throws -> [PrivateMarker]
    func count(postId: UUID) async throws -> Int
    /// Author flips their own reply's privacy (either direction).
    func setMyPrivacy(replyId: UUID, isPrivate: Bool) async throws
    /// Owner buries a public reply (public -> private). Owner cannot reveal.
    func ownerPrivatize(replyId: UUID) async throws
}

final class LiveRepliesService: RepliesService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    private struct SubmitParams: Encodable {
        let p_owner: String
        let p_prompt: String
        let p_body: String
        let p_is_private: Bool
    }

    private struct PrivacyParams: Encodable {
        let p_reply_id: String
        let p_private: Bool
    }

    private struct OpenPostParams: Encodable {
        let p_owner: String
        let p_prompt: String
        let p_level: String
    }

    private struct SetPostSpiceParams: Encodable {
        let p_post: String
        let p_level: String
    }

    func submit(ownerId: UUID, promptId: UUID, body: String, isPrivate: Bool) async throws {
        try await client.rpc("submit_reply", params: SubmitParams(
            p_owner: ownerId.uuidString,
            p_prompt: promptId.uuidString,
            p_body: body,
            p_is_private: isPrivate
        )).execute()
    }

    func openPost(ownerId: UUID, promptId: UUID, level: String) async throws {
        try await client.rpc("open_post", params: OpenPostParams(
            p_owner: ownerId.uuidString,
            p_prompt: promptId.uuidString,
            p_level: level
        )).execute()
    }

    func setPostSpice(postId: UUID, level: String) async throws {
        try await client.rpc("set_post_spice", params: SetPostSpiceParams(
            p_post: postId.uuidString,
            p_level: level
        )).execute()
    }

    func publicReplies(postId: UUID) async throws -> [Reply] {
        try await client
            .from("replies").select()
            .eq("post_id", value: postId.uuidString)
            .eq("is_private", value: false)
            .order("created_at", ascending: true)
            .execute().value
    }

    func myReply(postId: UUID) async throws -> Reply? {
        guard let me = client.auth.currentUser?.id else { return nil }
        let rows: [Reply] = try await client
            .from("replies").select()
            .eq("post_id", value: postId.uuidString)
            .eq("author_id", value: me.uuidString)
            .limit(1).execute().value
        return rows.first
    }

    func privateMarkers(postId: UUID) async throws -> [PrivateMarker] {
        try await client
            .rpc("post_private_markers", params: ["p_post_id": postId.uuidString])
            .execute().value
    }

    func count(postId: UUID) async throws -> Int {
        try await client
            .rpc("post_reply_count", params: ["p_post_id": postId.uuidString])
            .execute().value
    }

    func setMyPrivacy(replyId: UUID, isPrivate: Bool) async throws {
        try await client.rpc("set_my_reply_privacy", params: PrivacyParams(
            p_reply_id: replyId.uuidString,
            p_private: isPrivate
        )).execute()
    }

    func ownerPrivatize(replyId: UUID) async throws {
        try await client
            .rpc("owner_privatize_reply", params: ["p_reply_id": replyId.uuidString])
            .execute()
    }
}
