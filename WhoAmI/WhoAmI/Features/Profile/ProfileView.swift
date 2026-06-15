import SwiftUI

/// Used both as the "You" tab (ownerId == nil) and pushed for someone else's profile.
/// Does NOT wrap itself in a NavigationStack — the enclosing context provides one.
struct ProfileView: View {
    var ownerId: UUID? = nil
    var title: String? = nil

    @Environment(AppContainer.self) private var container
    @State private var vm: ProfileViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(title ?? "You")
        .toolbar {
            if ownerId == nil {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button("Sign out", role: .destructive) {
                            Task { await container.session.signOut() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onAppear {
            if vm == nil {
                let model = ProfileViewModel(
                    ownerId: ownerId,
                    posts: container.posts,
                    prompts: container.prompts,
                    replies: container.replies,
                    gists: container.gists
                )
                vm = model
                Task { await model.load() }
            }
        }
        .refreshable { await vm?.load() }
    }

    @ViewBuilder
    private func content(_ vm: ProfileViewModel) -> some View {
        List {
            if let verdict = vm.heroVerdict {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Who you are right now")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(verdict).font(.title3.bold())
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Prompts") {
                if vm.rows.isEmpty && !vm.loading {
                    Text(vm.ownerId == nil
                         ? "No posts yet. Your profile fills in as friends answer prompts about you."
                         : "Nothing here yet.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(vm.rows) { row in
                    PostRowView(row: row, isOwner: vm.ownerId == nil)
                }
            }

            if let error = vm.error {
                Text(error).foregroundStyle(.red)
            }
        }
    }
}
