import Foundation

/// Mirrors `public.gists`.
struct Gist: Codable, Identifiable, Sendable {
    let id: UUID
    let postId: UUID
    var currentVersionId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case postId = "post_id"
        case currentVersionId = "current_version_id"
    }
}

/// Mirrors `public.gist_versions` — append-only history that powers the evolution feature.
struct GistVersion: Codable, Identifiable, Sendable {
    let id: UUID
    let gistId: UUID
    var verdict: String?
    var body: String
    var model: String?
    var toneFlag: String?
    var excludedCount: Int
    var replyCountAtGeneration: Int
    /// Set true when a revoke drops the graduated post below MIN_FLOOR (3) public replies —
    /// surfaces a "based on fewer voices now" badge on the portrait.
    var stale: Bool
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case gistId = "gist_id"
        case verdict
        case body
        case model
        case toneFlag = "tone_flag"
        case excludedCount = "excluded_count"
        case replyCountAtGeneration = "reply_count_at_generation"
        case stale
        case createdAt = "created_at"
    }
}
