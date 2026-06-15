import SwiftUI

/// Doubles as the owner's "curate" view: the owner can hide public replies, and any author
/// can reveal/re-hide their own reply. Private replies show only as named, locked markers.
/// When a gist exists, offers the share-card and the evolution timeline.
struct PostDetailView: View {
    let postId: UUID
    let promptText: String
    let isOwner: Bool

    @Environment(AppContainer.self) private var container
    @State private var vm: PostDetailViewModel?
    @State private var showingShare = false

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
                let model = PostDetailViewModel(
                    postId: postId,
                    isOwner: isOwner,
                    gists: container.gists,
                    replies: container.replies,
                    profile: container.profile,
                    myId: container.auth.currentUserID
                )
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
                    NavigationLink("See how this evolved") {
                        GistEvolutionView(postId: postId)
                    }
                    .font(.subheadline)
                } else {
                    Text("No AI gist yet — showing the raw replies below. (The gist generates server-side once the generate-gist function runs.)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let mine = vm.myReply {
                Section("Your reply") {
                    Text(mine.body)
                    if mine.isPrivate {
                        Label("Private — only you can read this.", systemImage: "lock.fill")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Reveal to everyone") { Task { await vm.setMyPrivacy(false) } }
                    } else {
                        Button("Make private") { Task { await vm.setMyPrivacy(true) } }
                    }
                }
            }

            Section("Replies (\(vm.count))") {
                ForEach(vm.otherPublicReplies) { reply in
                    ReplyRowView(
                        authorName: vm.name(for: reply.authorId),
                        reply: reply,
                        canHide: vm.isOwner,
                        onHide: { Task { await vm.ownerPrivatize(reply.id) } }
                    )
                }
                ForEach(vm.visibleMarkers) { marker in
                    Label("\(marker.displayName ?? "Someone") left a private reply", systemImage: "lock.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                if vm.otherPublicReplies.isEmpty && vm.visibleMarkers.isEmpty && !vm.loading {
                    Text("No other replies to show yet.").font(.footnote).foregroundStyle(.secondary)
                }
            }

            if let error = vm.error {
                Text(error).foregroundStyle(.red)
            }
        }
        .toolbar {
            if let gist = vm.gist {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share gist")
                    .opacity(gist.verdict == nil && gist.body.isEmpty ? 0 : 1)
                }
            }
        }
        .sheet(isPresented: $showingShare) {
            if let gist = vm.gist {
                GistShareView(verdict: gist.verdict ?? "Your gist", text: gist.body, prompt: promptText)
            }
        }
    }
}
