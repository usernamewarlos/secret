import Foundation
import Observation

@MainActor
@Observable
final class AnswerViewModel {
    /// Client-side reply cap mirroring the DB `replies_body_len` CHECK.
    static let maxLength = 500

    var body = ""
    var isPrivate = false
    var busy = false
    var error: String?

    let prompt: Prompt
    let owner: UserProfile
    private let replies: RepliesService

    var characterCount: Int { body.count }
    var isOverLimit: Bool { characterCount > Self.maxLength }

    /// Submit is allowed only with non-empty, in-limit text and no in-flight request.
    var canSubmit: Bool {
        !busy
            && !isOverLimit
            && !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(replies: RepliesService, prompt: Prompt, owner: UserProfile) {
        self.replies = replies
        self.prompt = prompt
        self.owner = owner
    }

    func submit() async -> Bool {
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            error = "Write something first."
            return false
        }
        guard !isOverLimit else {
            error = "Keep it under \(Self.maxLength) characters."
            return false
        }
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await replies.submit(ownerId: owner.id, promptId: prompt.id, body: text, isPrivate: isPrivate)
            return true
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }
}
