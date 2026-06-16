import Foundation

enum PostStatus: String, Codable, Sendable {
    case accumulating
    case graduated
    case expired
}

/// Mirrors `public.posts`.
struct Post: Codable, Identifiable, Sendable {
    let id: UUID
    let profileOwnerId: UUID
    let promptId: UUID
    var status: PostStatus
    var threshold: Int
    var graduatedAt: String?
    /// Effective per-post tone the gist generator calibrates to: wholesome | playful | social | spicy.
    var spiceLevel: String

    enum CodingKeys: String, CodingKey {
        case id
        case profileOwnerId = "profile_owner_id"
        case promptId = "prompt_id"
        case status
        case threshold
        case graduatedAt = "graduated_at"
        case spiceLevel = "spice_level"
    }
}
