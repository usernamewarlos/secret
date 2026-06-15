import SwiftUI

struct PostDetailView: View {
    let postId: UUID
    let promptText: String
    let isOwner: Bool

    @Environment(AppContainer.self) private var container
    @State private var vm: PostDetailViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Gist")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if vm == nil {
                let model = PostDetailViewModel(postId: postId, isOwner: isOwner, gists: container.gists, replies: container.replies)
                vm = model
                Task { await model.load() }
            }
        }
        .refreshable { await vm?.load() }
    }

    @ViewBuilder
    private func content(_ vm: PostDetailViewModel) -> some View {
        List {
            Section {
                Text(promptText).font(.headline)
            }

            Section("The gist") {
                if let gist = vm.gist {
                    if let verdict = gist.verdict {
                        Text(verdict).font(.title3.bold())
                    }
                    Text(gist.body)
                    if let flag = gist.toneFlag, flag != "ok" {
                        Text("tone: \(flag)").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("No AI gist yet — showing the raw replies below. (The gist generates server-side once the generate-gist function runs.)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Replies (\(vm.count))") {
                ForEach(vm.publicReplies) { reply in
                    ReplyRowView(reply: reply, isOwner: vm.isOwner) {
                        Task { await vm.ownerPrivatize(reply.id) }
                    }
                }
                ForEach(vm.markers) { marker in
                    Label("\(marker.displayName ?? "Someone") left a private reply", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if vm.publicReplies.isEmpty && vm.markers.isEmpty && !vm.loading {
                    Text("No replies to show yet.").font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let error = vm.error {
                Text(error).foregroundStyle(.red)
            }
        }
    }
}
