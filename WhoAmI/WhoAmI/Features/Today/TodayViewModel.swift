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

    /// Owner-side spice choice for today's prompt, including the "closed" (Skip) state.
    /// Ordered so it can be compared against / capped at the prompt's tone.
    enum SpiceChoice: Int, CaseIterable, Identifiable {
        case skip = -1
        case wholesome = 0
        case playful = 1
        case social = 2
        case spicy = 3

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .skip: return "Skip"
            case .wholesome: return "Wholesome"
            case .playful: return "Playful"
            case .social: return "Social"
            case .spicy: return "Spicy"
            }
        }

        /// The RPC level string, or nil for `.skip` (no open).
        var level: String? {
            switch self {
            case .skip: return nil
            case .wholesome: return "wholesome"
            case .playful: return "playful"
            case .social: return "social"
            case .spicy: return "spicy"
            }
        }

        init(tone: PromptTone) {
            switch tone {
            case .wholesome: self = .wholesome
            case .playful: self = .playful
            case .social: self = .social
            case .spicy: self = .spicy
            }
        }

        init(level: String) {
            switch level {
            case "wholesome": self = .wholesome
            case "playful": self = .playful
            case "social": self = .social
            case "spicy": self = .spicy
            default: self = .skip
            }
        }
    }

    var prompt: Prompt?
    var targets: [Target] = []
    var loading = true
    var error: String?

    // Owner-side ("Today — about you") spice control state.
    var currentUserId: UUID?
    /// The level the owner has chosen for their own post on today's prompt.
    var ownerChoice: SpiceChoice = .skip
    /// The owner's comfort (default) level, used to decide opt-in for spicier prompts.
    private var comfort: SpiceChoice = .social
    var spiceBusy = false
    var spiceError: String?

    private let prompts: PromptsService
    private let connections: ConnectionsService
    private let posts: PostsService
    private let replies: RepliesService
    private let profile: ProfileService
    private let auth: AuthService

    init(
        prompts: PromptsService,
        connections: ConnectionsService,
        posts: PostsService,
        replies: RepliesService,
        profile: ProfileService,
        auth: AuthService
    ) {
        self.prompts = prompts
        self.connections = connections
        self.posts = posts
        self.replies = replies
        self.profile = profile
        self.auth = auth
    }

    /// Choices the owner may pick, capped at the prompt's own tone, with "Skip" always available.
    var availableChoices: [SpiceChoice] {
        guard let tone = prompt?.tone else { return [.skip] }
        let cap = SpiceChoice(tone: tone)
        return [.skip] + SpiceChoice.allCases.filter { $0.rawValue >= 0 && $0.rawValue <= cap.rawValue }
    }

    /// True when the prompt's tone is spicier than the owner's comfort level — the post stays
    /// closed (opt-in) until the owner explicitly picks a level.
    var requiresOptIn: Bool {
        guard let tone = prompt?.tone else { return false }
        return SpiceChoice(tone: tone).rawValue > comfort.rawValue
    }

    func load() async {
        loading = true
        error = nil
        currentUserId = auth.currentUserID
        do {
            async let promptTask = prompts.today()
            async let targetsTask = connections.replyTargets()
            let (prompt, owners) = try await (promptTask, targetsTask)
            self.prompt = prompt

            // Owner comfort level from their profile default.
            if let uid = currentUserId,
               let me = try? await profile.fetch(id: uid),
               let level = me.defaultSpiceLevel {
                comfort = SpiceChoice(level: level)
            }

            guard let prompt else {
                self.targets = owners.map { Target(owner: $0, answered: false) }
                loading = false
                return
            }

            // Reflect the owner's existing post (if any) into the control.
            if let uid = currentUserId,
               let myPost = try? await posts.post(ownerId: uid, promptId: prompt.id) {
                ownerChoice = SpiceChoice(level: myPost.spiceLevel)
            } else {
                // No post yet: default to the prompt tone unless it exceeds comfort (opt-in).
                ownerChoice = requiresOptIn ? .skip : SpiceChoice(tone: prompt.tone)
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

    /// Apply the owner's chosen spice level to their own post for today's prompt.
    /// `.skip` leaves the prompt closed (no open call).
    func applySpice(_ choice: SpiceChoice) async {
        ownerChoice = choice
        guard let prompt, let uid = currentUserId else { return }
        guard let level = choice.level else {
            // Skip: nothing to open. (No RPC to close an unopened prompt.)
            spiceError = nil
            return
        }
        spiceBusy = true
        spiceError = nil
        defer { spiceBusy = false }
        do {
            try await replies.openPost(ownerId: uid, promptId: prompt.id, level: level)
        } catch {
            spiceError = friendlyMessage(for: error)
        }
    }

    private func friendlyMessage(for error: Error) -> String {
        let raw = error.localizedDescription
        if raw.contains("owner has not opened this prompt") {
            return "this prompt needs the owner to opt in via openPost"
        }
        return raw
    }

    func markAnswered(_ ownerId: UUID) {
        if let index = targets.firstIndex(where: { $0.owner.id == ownerId }) {
            targets[index].answered = true
        }
    }
}
