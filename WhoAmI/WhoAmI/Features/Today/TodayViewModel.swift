import Foundation
import Observation

@MainActor
@Observable
final class TodayViewModel {
    struct Target: Identifiable {
        let owner: UserProfile
        var answered: Bool
        var id: UUID { owner.id }
    }

    var prompt: Prompt?
    var targets: [Target] = []
    var loading = true
    var error: String?

    private let prompts: PromptsService
    private let connections: ConnectionsService
    private let posts: PostsService
    private let replies: RepliesService

    init(prompts: PromptsService, connections: ConnectionsService, posts: PostsService, replies: RepliesService) {
        self.prompts = prompts
        self.connections = connections
        self.posts = posts
        self.replies = replies
    }

    func load() async {
        loading = true
        error = nil
        do {
            async let promptTask = prompts.today()
            async let targetsTask = connections.replyTargets()
            let (prompt, owners) = try await (promptTask, targetsTask)
            self.prompt = prompt

            guard let prompt else {
                self.targets = owners.map { Target(owner: $0, answered: false) }
                loading = false
                return
            }

            var result: [Target] = []
            for owner in owners {
                var answered = false
                if let post = try? await posts.post(ownerId: owner.id, promptId: prompt.id),
                   (try? await replies.myReply(postId: post.id)) != nil {
                    answered = true
                }
                result.append(Target(owner: owner, answered: answered))
            }
            self.targets = result
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func markAnswered(_ ownerId: UUID) {
        if let index = targets.firstIndex(where: { $0.owner.id == ownerId }) {
            targets[index].answered = true
        }
    }
}
