import Foundation

/// Mirrors `public.replies`. NOTE: a private reply's `body` is only ever returned by the
/// API to its author — RLS guarantees the owner never receives it (PRODUCT.md §10).
struct Reply: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: UUID
    let authorId: UUID
    let body: String
    var isPrivate: Bool
    var privatizedBy: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case authorId = "author_id"
        case body
        case isPrivate = "is_private"
        case privatizedBy = "privatized_by"
        case createdAt = "created_at"
    }
}

/// What others see for a private reply: author identity only, never the body
/// (from `post_private_markers`). Renders as "🔒 [name] left a private reply".
struct PrivateMarker: Codable, Identifiable, Sendable {
    var id: UUID { authorId }
    let authorId: UUID
    let displayName: String?

    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case displayName = "display_name"
    }
}
