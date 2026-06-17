import Foundation
import Observation

/// Drives the Today screen under per-profile prompt rotation: one `today_feed` RPC
/// returns the caller's own rotated prompt plus each person they can answer about
/// (each on their OWN rotated prompt). The spice control sets the caller's standing
/// level, which reshapes which prompts rotate onto their profile.
@MainActor
@Observable
final class TodayViewModel {
    var feed: TodayFeed?
    var loading = true
    var error: String?

    /// The caller's standing spice ceiling (drives their own rotation band).
    var myLevel: String = "social"
    var spiceBusy = false

    private let prompts: PromptsService
    private let profile: ProfileService
    private let auth: AuthService

    init(prompts: PromptsService, profile: ProfileService, auth: AuthService) {
        self.prompts = prompts
        self.profile = profile
        self.auth = auth
    }

    var myPrompt: TodayFeed.MyPrompt? { feed?.myPrompt }
    var targets: [TodayTarget] { feed?.targets ?? [] }

    func load() async {
        loading = true
        error = nil
        do {
            async let feedTask = prompts.todayFeed()
            if let uid = auth.currentUserID,
               let me = try? await profile.fetch(id: uid),
               let level = me.defaultSpiceLevel {
                myLevel = level
            }
            feed = try await feedTask
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    /// Change the caller's standing spice level, then reload so the rotation (their
    /// own prompt) reflects the new band.
    func setSpice(_ level: String) async {
        guard level != myLevel else { return }
        spiceBusy = true
        let previous = myLevel
        myLevel = level
        do {
            try await profile.setDefaultSpice(level: level)
            await load()
        } catch {
            myLevel = previous
            self.error = error.localizedDescription
        }
        spiceBusy = false
    }

    /// Mark a target answered locally (and bump its counter) after a reply is sent.
    func markAnswered(_ ownerId: UUID) {
        guard var f = feed, let i = f.targets.firstIndex(where: { $0.ownerId == ownerId }) else { return }
        f.targets[i].answered = true
        f.targets[i] = TodayTarget(
            ownerId: f.targets[i].ownerId,
            name: f.targets[i].name,
            handle: f.targets[i].handle,
            promptId: f.targets[i].promptId,
            promptText: f.targets[i].promptText,
            promptTone: f.targets[i].promptTone,
            status: f.targets[i].status,
            count: f.targets[i].count + 1,
            threshold: f.targets[i].threshold,
            answered: true
        )
        feed = f
    }

    /// The prompt to hand AnswerView when answering about a target.
    func prompt(for t: TodayTarget) -> Prompt {
        Prompt(id: t.promptId, text: t.promptText, tone: t.promptTone, publishDate: nil)
    }

    /// A lightweight owner profile for AnswerView (name + handle are all it needs).
    func owner(for t: TodayTarget) -> UserProfile {
        UserProfile(
            id: t.ownerId, displayName: t.name, photoURL: nil, bio: nil, dob: nil,
            ageVerified: true, verifiedPhone: false, igHandle: t.handle,
            defaultSpiceLevel: nil, createdAt: nil
        )
    }
}
