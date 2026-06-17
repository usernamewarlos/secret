import Foundation

/// A profile's whole archive in one payload (from the `profile_feed` RPC) — replaces
/// the Profile screen's two N+1 client loops with a single call.
struct ProfileFeed: Codable, Sendable {
    struct Owner: Codable, Sendable {
        let displayName: String?
        let igHandle: String?
        let photoURL: String?
        let repliers: Int

        enum CodingKeys: String, CodingKey {
            case displayName = "display_name"
            case igHandle = "ig_handle"
            case photoURL = "photo_url"
            case repliers
        }
    }

    struct Post: Codable, Identifiable, Sendable {
        let id: UUID
        let status: PostStatus
        let threshold: Int
        let spiceLevel: String
        let graduatedAt: String?
        let promptId: UUID
        let promptText: String
        let promptTone: PromptTone
        let count: Int
        let privateCount: Int
        let verdict: String?
        /// Current gist version's tone flag (`ok|thin|hostile`) — drives a soft cue on the card.
        let toneFlag: String?
        /// True when a revoke thinned this graduated post below its voice floor. Optional so the
        /// app decodes against both the pre- and post-0014 `profile_feed` (key absent => nil).
        let stale: Bool?

        enum CodingKeys: String, CodingKey {
            case id, status, threshold
            case spiceLevel = "spice_level"
            case graduatedAt = "graduated_at"
            case promptId = "prompt_id"
            case promptText = "prompt_text"
            case promptTone = "prompt_tone"
            case count
            case privateCount = "private_count"
            case verdict
            case toneFlag = "tone_flag"
            case stale
        }
    }

    let owner: Owner
    let posts: [Post]
}
