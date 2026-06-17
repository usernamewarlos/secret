import Foundation
import Observation

/// Backs the You tab + someone-else's profile. One `profile_feed` RPC populates the
/// whole screen (owner header + archive with counts/private-counts/gist verdicts) —
/// replacing the old per-post N+1 loops.
@MainActor
@Observable
final class ProfileViewModel {
    let ownerId: UUID?          // nil == me
    let isOwner: Bool
    private let titleFallback: String?

    var owner: ProfileFeed.Owner?
    var posts: [ProfileFeed.Post] = []
    var loading = true
    var error: String?

    private let profile: ProfileService
    private let auth: AuthService

    init(ownerId: UUID?, titleFallback: String?, profile: ProfileService, auth: AuthService) {
        self.ownerId = ownerId
        self.isOwner = ownerId == nil
        self.titleFallback = titleFallback
        self.profile = profile
        self.auth = auth
    }

    /// First graduated post carrying a gist verdict — the hero portrait.
    var heroPost: ProfileFeed.Post? {
        posts.first { $0.status == .graduated && ($0.verdict?.isEmpty == false) }
    }

    var displayName: String {
        if let n = owner?.displayName, !n.isEmpty { return n }
        return titleFallback ?? (isOwner ? "You" : "Profile")
    }

    /// "@mayar · 4 repliers".
    var handleLine: String {
        let handle = (owner?.igHandle?.isEmpty == false) ? "@\(owner!.igHandle!)" : "@you"
        let r = owner?.repliers ?? 0
        return "\(handle) · \(r) replier\(r == 1 ? "" : "s")"
    }

    var photoURL: URL? {
        guard let s = owner?.photoURL, let url = URL(string: s) else { return nil }
        return url
    }

    func load() async {
        loading = true
        error = nil
        guard let id = ownerId ?? auth.currentUserID else { loading = false; return }
        do {
            let feed = try await profile.profileFeed(ownerId: id)
            owner = feed.owner
            posts = feed.posts
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}
