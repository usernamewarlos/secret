import Foundation
import Observation

@MainActor
@Observable
final class PostDetailViewModel {
    let postId: UUID
    let isOwner: Bool

    var gist: GistVersion?
    var publicReplies: [Reply] = []
    var markers: [PrivateMarker] = []
    var myReply: Reply?
    var authorNames: [UUID: String] = [:]
    var count = 0
    var loading = true
    var error: String?

    private let gists: GistService
    private let replies: RepliesService
    private let profile: ProfileService
    private let myId: UUID?

    init(postId: UUID, isOwner: Bool, gists: GistService, replies: RepliesService, profile: ProfileService, myId: UUID?) {
        self.postId = postId
        self.isOwner = isOwner
        self.gists = gists
        self.replies = replies
        self.profile = profile
        self.myId = myId
    }

    /// Public replies authored by other people (my own is shown in its own section).
    var otherPublicReplies: [Reply] {
        publicReplies.filter { $0.authorId != myId }
    }

    /// Private markers excluding me (I see my own private reply in its own section).
    var visibleMarkers: [PrivateMarker] {
        markers.filter { $0.authorId != myId }
    }

    func name(for id: UUID) -> String {
        authorNames[id] ?? "Someone"
    }

    func load() async {
        loading = true
        error = nil
        do {
            async let g = gists.currentVersion(postId: postId)
            async let pub = replies.publicReplies(postId: postId)
            async let mk = replies.privateMarkers(postId: postId)
            async let mine = replies.myReply(postId: postId)
            let (gist, pub2, mk2, mine2) = try await (g, pub, mk, mine)
            self.gist = gist
            self.publicReplies = pub2
            self.markers = mk2
            self.myReply = mine2
            self.count = (try? await replies.count(postId: postId)) ?? pub2.count

            var ids = Set(pub2.map(\.authorId))
            if let mine2 { ids.insert(mine2.authorId) }
            let profiles = try await profile.fetchMany(ids: Array(ids))
            authorNames = Dictionary(profiles.map { ($0.id, $0.displayName ?? "Someone") },
                                     uniquingKeysWith: { first, _ in first })
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    /// Owner buries another person's public reply (public -> private). Cannot reveal.
    func ownerPrivatize(_ replyId: UUID) async {
        do {
            try await replies.ownerPrivatize(replyId: replyId)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Author flips their own reply's privacy, either direction.
    func setMyPrivacy(_ isPrivate: Bool) async {
        guard let mine = myReply else { return }
        do {
            try await replies.setMyPrivacy(replyId: mine.id, isPrivate: isPrivate)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
