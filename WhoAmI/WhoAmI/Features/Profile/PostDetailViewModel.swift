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
    var count = 0
    var loading = true
    var error: String?

    private let gists: GistService
    private let replies: RepliesService

    init(postId: UUID, isOwner: Bool, gists: GistService, replies: RepliesService) {
        self.postId = postId
        self.isOwner = isOwner
        self.gists = gists
        self.replies = replies
    }

    func load() async {
        loading = true
        error = nil
        do {
            async let g = gists.currentVersion(postId: postId)
            async let pub = replies.publicReplies(postId: postId)
            async let mk = replies.privateMarkers(postId: postId)
            let (gist, pub2, mk2) = try await (g, pub, mk)
            self.gist = gist
            self.publicReplies = pub2
            self.markers = mk2
            self.count = (try? await replies.count(postId: postId)) ?? pub2.count
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func ownerPrivatize(_ replyId: UUID) async {
        do {
            try await replies.ownerPrivatize(replyId: replyId)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
