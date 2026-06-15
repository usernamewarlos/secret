import SwiftUI

struct ConnectionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: ConnectionsViewModel?
    @State private var showingAdd = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("People")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .onAppear {
                if vm == nil {
                    let model = ConnectionsViewModel(
                        connections: container.connections,
                        profile: container.profile,
                        myId: container.auth.currentUserID
                    )
                    vm = model
                    Task { await model.load() }
                }
            }
            .refreshable { await vm?.load() }
            .sheet(isPresented: $showingAdd) {
                if let vm { AddConnectionView(vm: vm) }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: ConnectionsViewModel) -> some View {
        List {
            if vm.rows.isEmpty && !vm.loading {
                Text("Add people to build your circle. Make someone a replier and they can answer prompts about you.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(vm.rows) { row in
                ConnectionRowView(
                    row: row,
                    onToggleRole: {
                        let next: ConnectionRole = row.connection.role == .replier ? .viewer : .replier
                        Task { await vm.setRole(connectionId: row.connection.id, role: next) }
                    },
                    onRevoke: { Task { await vm.revoke(row.connection.connectedUserId) } }
                )
            }
            if let error = vm.error {
                Text(error).foregroundStyle(.red)
            }
        }
    }
}

private struct ConnectionRowView: View {
    let row: ConnectionsViewModel.Row
    var onToggleRole: () -> Void
    var onRevoke: () -> Void

    var body: some View {
        NavigationLink {
            ProfileView(ownerId: row.user?.id ?? row.connection.connectedUserId,
                        title: row.user?.displayName)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.user?.displayName ?? "Someone")
                    if let ig = row.user?.igHandle, !ig.isEmpty {
                        Text("@\(ig)").font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Text(row.connection.role == .replier ? "Replier" : "Viewer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(row.connection.role == .replier ? Color.accentColor : .secondary)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Revoke", role: .destructive, action: onRevoke)
            Button(row.connection.role == .replier ? "Make viewer" : "Make replier", action: onToggleRole)
                .tint(.blue)
        }
    }
}
