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
