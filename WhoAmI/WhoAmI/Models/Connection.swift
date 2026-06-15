import Foundation

enum ConnectionRole: String, Codable, Sendable {
    case viewer
    case replier
}

/// Mirrors `public.connections`.
struct Connection: Codable, Identifiable, Sendable {
    let id: UUID
    let ownerId: UUID
    let connectedUserId: UUID
    var role: ConnectionRole
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case ownerId = "owner_id"
        case connectedUserId = "connected_user_id"
        case role
        case createdAt = "created_at"
    }
}
