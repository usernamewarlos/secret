import Foundation

enum PromptTone: String, Codable, Sendable {
    case wholesome
    case playful
    case social
    case spicy
}

/// Mirrors `public.prompts`.
struct Prompt: Codable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let tone: PromptTone
    var publishDate: String?

    enum CodingKeys: String, CodingKey {
        case id
        case text
        case tone
        case publishDate = "publish_date"
    }
}

/// One person the caller can answer about today, with THAT person's rotated
/// prompt + their post's aggregate state. From the `today_feed` RPC.
struct TodayTarget: Codable, Identifiable, Sendable {
    let ownerId: UUID
    let name: String?
    let handle: String?
    let promptId: UUID
    let promptText: String
    let promptTone: PromptTone
    let status: String
    let count: Int
    let threshold: Int
    var answered: Bool

    var id: UUID { ownerId }

    enum CodingKeys: String, CodingKey {
        case ownerId = "owner_id"
        case name, handle
        case promptId = "prompt_id"
        case promptText = "prompt_text"
        case promptTone = "prompt_tone"
        case status, count, threshold, answered
    }
}

/// The Today screen payload: the caller's own rotated prompt + the people they can
/// answer about (each on their own rotated prompt). From the `today_feed` RPC.
struct TodayFeed: Codable, Sendable {
    struct MyPrompt: Codable, Sendable {
        let id: UUID
        let text: String
        let tone: PromptTone
    }

    var myPrompt: MyPrompt?
    var myCount: Int
    var myStatus: String
    var myThreshold: Int
    var targets: [TodayTarget]

    enum CodingKeys: String, CodingKey {
        case myPrompt = "my_prompt"
        case myCount = "my_count"
        case myStatus = "my_status"
        case myThreshold = "my_threshold"
        case targets
    }
}
