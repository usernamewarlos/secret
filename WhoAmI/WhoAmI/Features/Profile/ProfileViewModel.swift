import Foundation
import Observation

@MainActor
@Observable
final class ProfileViewModel {
    struct Row: Identifiable {
        let post: Post
        let prompt: Prompt?
        let count: Int
        var id: UUID { post.id }
    }

    let ownerId: UUID?          // nil == me
    var rows: [Row] = []
    var heroVerdict: String?    // latest graduated gist verdict
    var loading = true
    var error: String?

    private let posts: PostsService
    private let prompts: PromptsService
    private let replies: RepliesService
    private let gists: GistService

    init(ownerId: UUID?, posts: PostsService, prompts: PromptsService, replies: RepliesService, gists: GistService) {
        self.ownerId = ownerId
        self.posts = posts
        self.prompts = prompts
        self.replies = replies
        self.gists = gists
    }

    func load() async {
        loading = true
        error = nil
        do {
            let postList = ownerId == nil ? try await posts.myPosts() : try await posts.posts(ownerId: ownerId!)
            var result: [Row] = []
            for post in postList {
                let prompt = try? await prompts.byId(post.promptId)
                let count = (try? await replies.count(postId: post.id)) ?? 0
                result.append(Row(post: post, prompt: prompt, count: count))
            }
            rows = result

            if let firstGraduated = postList.first(where: { $0.status == .graduated }),
               let version = try? await gists.currentVersion(postId: firstGraduated.id) {
                heroVerdict = version.verdict
            } else {
                heroVerdict = nil
            }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
