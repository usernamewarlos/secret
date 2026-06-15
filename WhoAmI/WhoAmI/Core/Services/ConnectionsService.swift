import Foundation
import Supabase

protocol ConnectionsService: Sendable {
    func list() async throws -> [Connection]
    func add(connectedUserId: UUID, role: ConnectionRole) async throws
    func setRole(connectionId: UUID, role: ConnectionRole) async throws
    func revoke(connectedUserId: UUID) async throws
    /// Owners who have made me a replier — the people I can answer prompts about.
    func replyTargets() async throws -> [UserProfile]
    func search(name: String) async throws -> [UserProfile]
    func block(userId: UUID) async throws
    func unblock(userId: UUID) async throws
    func blockedIds() async throws -> [UUID]
}

final class LiveConnectionsService: ConnectionsService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    func list() async throws -> [Connection] {
        try await client.from("connections").select().execute().value
    }

    func add(connectedUserId: UUID, role: ConnectionRole) async throws {
        guard let owner = client.auth.currentUser?.id else {
            throw AppError.message("Not signed in.")
        }
        struct Payload: Encodable {
            let owner_id: String
            let connected_user_id: String
            let role: String
        }
        try await client.from("connections").insert(
            Payload(owner_id: owner.uuidString, connected_user_id: connectedUserId.uuidString, role: role.rawValue)
        ).execute()
    }

    func setRole(connectionId: UUID, role: ConnectionRole) async throws {
        try await client.from("connections")
            .update(["role": role.rawValue])
            .eq("id", value: connectionId.uuidString)
            .execute()
    }

    /// Revoke = remove the person AND all their replies on my posts (server-side RPC).
    func revoke(connectedUserId: UUID) async throws {
        try await client
            .rpc("revoke_connection", params: ["p_connected": connectedUserId.uuidString])
            .execute()
    }

    func replyTargets() async throws -> [UserProfile] {
        guard let me = client.auth.currentUser?.id else { return [] }
        let conns: [Connection] = try await client.from("connections").select()
            .eq("connected_user_id", value: me.uuidString)
            .eq("role", value: ConnectionRole.replier.rawValue)
            .execute().value
        let ownerIds = conns.map { $0.ownerId.uuidString }
        guard !ownerIds.isEmpty else { return [] }
        return try await client.from("users").select()
            .in("id", values: ownerIds)
            .execute().value
    }

    func search(name: String) async throws -> [UserProfile] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await client.from("users").select()
            .ilike("display_name", pattern: "%\(trimmed)%")
            .limit(20).execute().value
    }

    func block(userId: UUID) async throws {
        guard let me = client.auth.currentUser?.id else { throw AppError.message("Not signed in.") }
        struct Payload: Encodable { let blocker_id: String; let blocked_id: String }
        try await client.from("blocks")
            .insert(Payload(blocker_id: me.uuidString, blocked_id: userId.uuidString))
            .execute()
    }

    func unblock(userId: UUID) async throws {
        guard let me = client.auth.currentUser?.id else { return }
        try await client.from("blocks").delete()
            .eq("blocker_id", value: me.uuidString)
            .eq("blocked_id", value: userId.uuidString)
            .execute()
    }

    func blockedIds() async throws -> [UUID] {
        struct Row: Decodable { let blocked_id: UUID }
        let rows: [Row] = try await client.from("blocks").select("blocked_id").execute().value
        return rows.map(\.blocked_id)
    }
}
