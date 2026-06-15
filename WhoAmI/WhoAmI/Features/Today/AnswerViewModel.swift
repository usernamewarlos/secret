import Foundation
import Observation

@MainActor
@Observable
final class AnswerViewModel {
    var body = ""
    var isPrivate = false
    var busy = false
    var error: String?

    let prompt: Prompt
    let owner: UserProfile
    private let replies: RepliesService

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
