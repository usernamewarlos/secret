import Foundation
import Supabase

protocol ConnectionsService: Sendable {
    func list() async throws -> [Connection]
    func add(connectedUserId: UUID, role: ConnectionRole) async throws
    func setRole(connectionId: UUID, role: ConnectionRole) async throws
    func revoke(connectedUserId: UUID) async throws
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
}
