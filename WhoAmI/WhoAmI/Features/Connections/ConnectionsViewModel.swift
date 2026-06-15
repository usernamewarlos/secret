import Foundation
import Observation

@MainActor
@Observable
final class ConnectionsViewModel {
    struct Row: Identifiable {
        let connection: Connection
        let user: UserProfile?
        var id: UUID { connection.id }
    }

    var rows: [Row] = []
    var loading = true
    var error: String?

    // Add-sheet state
    var searchText = ""
    var searchResults: [UserProfile] = []
    var searching = false

    private let connections: ConnectionsService
    private let profile: ProfileService
    private let myId: UUID?

    init(connections: ConnectionsService, profile: ProfileService, myId: UUID?) {
        self.connections = connections
        self.profile = profile
        self.myId = myId
    }

    func load() async {
        loading = true
        error = nil
        do {
            let all = try await connections.list()
            let mine = all.filter { $0.ownerId == myId }
            let users = try await profile.fetchMany(ids: mine.map(\.connectedUserId))
            let byId = Dictionary(users.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            rows = mine.map { Row(connection: $0, user: byId[$0.connectedUserId]) }
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    func search() async {
        searching = true
        let found = (try? await connections.search(name: searchText)) ?? []
        let existing = Set(rows.compactMap { $0.user?.id })
        searchResults = found.filter { $0.id != myId && !existing.contains($0.id) }
        searching = false
    }

    func add(_ user: UserProfile, role: ConnectionRole) async {
        do {
            try await connections.add(connectedUserId: user.id, role: role)
            searchResults.removeAll { $0.id == user.id }
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func setRole(connectionId: UUID, role: ConnectionRole) async {
        do {
            try await connections.setRole(connectionId: connectionId, role: role)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func revoke(_ connectedUserId: UUID) async {
        do {
            try await connections.revoke(connectedUserId: connectedUserId)
            await load()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
