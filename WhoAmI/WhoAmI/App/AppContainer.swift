import Foundation
import Observation

/// Composition root. Owns the live services and the session store, injected into the
/// view tree via the SwiftUI environment (see `WhoAmIApp`). Services are protocol-typed
/// so features depend on abstractions and tests can substitute mocks.
@MainActor
@Observable
final class AppContainer {
    let auth: AuthService
    let profile: ProfileService
    let connections: ConnectionsService
    let prompts: PromptsService
    let posts: PostsService
    let replies: RepliesService
    let gists: GistService
    let notifications: NotificationService
    let session: SessionStore

    init() {
        let auth = LiveAuthService()
        let profile = LiveProfileService()
        self.auth = auth
        self.profile = profile
        self.connections = LiveConnectionsService()
        self.prompts = LivePromptsService()
        self.posts = LivePostsService()
        self.replies = LiveRepliesService()
        self.gists = LiveGistService()
        self.notifications = LocalNotificationService()
        self.session = SessionStore(auth: auth, profile: profile)
    }
}
