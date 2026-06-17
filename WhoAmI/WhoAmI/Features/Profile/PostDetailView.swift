import SwiftUI

/// Doubles as the owner's "curate" view: the owner can hide public replies, and any author
/// can reveal/re-hide their own reply. Private replies show only as named, locked markers.
/// When a gist exists, offers the share-card and the evolution timeline.
///
/// Restyled to the Grapevine design system ("Post detail" screen): a full grape `GistCard`,
/// a "See replies / Hide replies" pill toggle, the "THE RAW REPLIES · ATTRIBUTED" stack of
/// `ReplyBubble`s, a "LOCKED · AUTHOR ONLY" stack of `LockChip`s, an info note explaining
/// privatize vs. reveal, and a stale badge when the gist dropped below its voice floor.
struct PostDetailView: View {
    let postId: UUID
    let promptText: String
    let isOwner: Bool

    @Environment(AppContainer.self) private var container
    @State private var vm: PostDetailViewModel?
    @State private var showingShare = false
    @State private var expanded = false
    @State private var pendingConfirm: GVConfirm?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Group {
                if let vm {
                    content(vm)
                } else {
                    ProgressView()
                        .tint(Theme.primary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .navigationTitle("Gist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let vm, let gist = vm.gist, !(gist.verdict == nil && gist.body.isEmpty) {
                ToolbarItem(placement: .primaryAction) {
                    GVIconButton(
                        icon: "square.and.arrow.up",
                        variant: .primary,
                        size: .sm,
                        accessibilityLabel: "Share gist"
                    ) {
                        showingShare = true
                    }
                }
            }
        }
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
        .sheet(isPresented: $showingShare) {
            if let vm, let gist = vm.gist {
                GistShareView(verdict: gist.verdict ?? "Your gist", text: gist.body, prompt: promptText)
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: PostDetailViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x5) {
                gistSection(vm)

                seeRepliesToggle(vm)

                if expanded {
                    expandedReplies(vm)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                if let error = vm.error {
                    errorNote(error)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x4)
            .padding(.bottom, Theme.Space.x10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollIndicators(.hidden)
        .animation(Theme.Motion.spring, value: expanded)
        .gvConfirm($pendingConfirm)
    }

    // MARK: - The gist (hero card)

    @ViewBuilder
    private func gistSection(_ vm: PostDetailViewModel) -> some View {
        if let gist = vm.gist {
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                GistCard(
                    gist: gistText(gist),
                    prompt: promptText,
                    replyCount: vm.count,
                    date: gistDate(gist),
                    surface: .grape,
                    size: .sm
                )

                if gist.stale {
                    staleBadge
                }

                // Subtle provenance + tone-flag meta, in the brand's muted voice.
                Text("An AI take on what your friends said — in their words, in their eyes.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)

                // Soft, friendly framing for thin/hostile sets — never the raw flag string,
                // and the hostile copy gentles rather than amplifies (GIST.md §8).
                switch gist.toneFlag {
                case "thin":
                    Text("Still taking shape — more friends will sharpen this.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                case "hostile":
                    Text("Your friends came in hot — we kept this one gentle.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                default:
                    EmptyView()
                }

                NavigationLink {
                    GistEvolutionView(postId: postId)
                } label: {
                    HStack(spacing: Theme.Space.x2) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14, weight: .bold))
                        Text("See how this evolved")
                            .font(BrandFont.hanken(14, .bold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.textFaint)
                    }
                    .foregroundStyle(Theme.text)
                    .padding(.vertical, Theme.Space.x3)
                }
            }

            if let mine = vm.myReply {
                yourReply(vm, mine: mine)
            }
        } else {
            GVCard(elevation: .low) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("NO GIST YET")
                        .gvKicker(Theme.textMuted)
                    Text("Showing the raw replies below. The gist generates once enough friends weigh in.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let mine = vm.myReply {
                yourReply(vm, mine: mine)
            }
        }
    }

    // MARK: - Your reply

    @ViewBuilder
    private func yourReply(_ vm: PostDetailViewModel, mine: Reply) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text("YOUR REPLY")
                .gvKicker(Theme.textMuted)

            GVCard(elevation: .flat) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text(mine.body)
                        .font(BrandFont.hanken(16, .regular))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(16 * 0.5)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if mine.isPrivate {
                        HStack(spacing: Theme.Space.x2) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("Private — only you can read this.")
                                .font(BrandFont.mono(12, .bold))
                        }
                        .foregroundStyle(Theme.lock)

                        GVButton(
                            "Reveal to everyone",
                            variant: .intrigue,
                            size: .sm,
                            icon: "eye.fill"
                        ) {
                            pendingConfirm = GVConfirm(
                                title: "Reveal your reply?",
                                message: "Your private reply becomes visible to everyone who can see this profile. This can't be undone.",
                                confirmTitle: "Reveal",
                                destructive: true
                            ) {
                                Task { await vm.setMyPrivacy(false) }
                            }
                        }
                    } else {
                        GVButton(
                            "Make private",
                            variant: .secondary,
                            size: .sm,
                            icon: "lock.fill"
                        ) {
                            Task { await vm.setMyPrivacy(true) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - See / Hide replies toggle

    private func seeRepliesToggle(_ vm: PostDetailViewModel) -> some View {
        let visibleCount = vm.otherPublicReplies.count + vm.visibleMarkers.count
        let label = expanded
            ? "Hide replies"
            : (visibleCount > 0 ? "See \(visibleCount) replies" : "See replies")
        let icon = expanded ? "chevron.up" : "chevron.down"

        return Button {
            expanded.toggle()
        } label: {
            HStack(spacing: Theme.Space.x2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(label)
                    .font(BrandFont.hanken(14, .bold))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                Capsule(style: .continuous).fill(Theme.surface2)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Expanded replies

    @ViewBuilder
    private func expandedReplies(_ vm: PostDetailViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x5) {

            // Attributed public replies.
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                Text("THE RAW REPLIES · ATTRIBUTED")
                    .gvKicker(Theme.textMuted)

                if vm.otherPublicReplies.isEmpty && !vm.loading {
                    Text("No public replies to show yet.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textFaint)
                } else {
                    ForEach(vm.otherPublicReplies) { reply in
                        ReplyBubble(
                            name: vm.name(for: reply.authorId),
                            body: reply.body,
                            time: relativeTime(reply.createdAt),
                            canPrivatize: vm.isOwner,
                            onPrivatize: {
                                pendingConfirm = GVConfirm(
                                    title: "Make this private?",
                                    message: "This buries their reply so no one can read it. It isn't deleted, and you can't undo it.",
                                    confirmTitle: "Make private",
                                    destructive: true
                                ) {
                                    Task { await vm.ownerPrivatize(reply.id) }
                                }
                            }
                        )
                    }
                }
            }

            // Locked, author-only private replies — named, never read.
            if !vm.visibleMarkers.isEmpty {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("LOCKED · AUTHOR ONLY")
                        .gvKicker(Theme.lock)

                    ForEach(vm.visibleMarkers) { marker in
                        LockChip(name: marker.displayName ?? "Someone", variant: .list)
                    }
                }
            }

            // Info note: privatize vs. reveal.
            if vm.isOwner {
                privatizeInfoNote
            }
        }
    }

    // MARK: - Pieces

    /// Lock-tinted note explaining the privatize / reveal asymmetry to the owner.
    private var privatizeInfoNote: some View {
        HStack(alignment: .top, spacing: Theme.Space.x3) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(Theme.lock)

            Text("You can **privatize** a public reply to bury it — never delete. Private replies even you can't read; only the author can reveal them.")
                .font(BrandFont.hanken(13, .regular))
                .foregroundStyle(Theme.textMuted)
                .lineSpacing(13 * 0.5)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.lockBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.lockBorder, lineWidth: 1)
        )
    }

    /// Warning-tinted badge when a revoke dropped the gist below its public-reply floor.
    private var staleBadge: some View {
        HStack(spacing: Theme.Space.x2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 13, weight: .bold))
            Text("Based on fewer voices now")
                .font(BrandFont.mono(11, .bold))
                .tracking(0.6)
                .textCase(.uppercase)
        }
        .foregroundStyle(Theme.warning)
        .padding(.vertical, 6)
        .padding(.horizontal, Theme.Space.x4)
        .background(
            Capsule(style: .continuous).fill(Theme.warning.opacity(0.14))
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(Theme.warning.opacity(0.35), lineWidth: 1)
        )
    }

    private func errorNote(_ message: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x3) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.danger)
            Text(message)
                .font(Theme.label)
                .foregroundStyle(Theme.danger)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func gistText(_ gist: GistVersion) -> String {
        if let verdict = gist.verdict, !verdict.isEmpty {
            return verdict
        }
        return gist.body
    }

    private func gistDate(_ gist: GistVersion) -> String? {
        guard let raw = gist.createdAt, let date = Self.parseISO(raw) else { return nil }
        return Self.monthYear.string(from: date)
    }

    /// Compact relative time ("2h", "3d") for a reply timestamp; nil when unparseable.
    private func relativeTime(_ raw: String?) -> String? {
        guard let raw, let date = Self.parseISO(raw) else { return nil }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60:        return "now"
        case ..<3_600:     return "\(Int(seconds / 60))m"
        case ..<86_400:    return "\(Int(seconds / 3_600))h"
        case ..<604_800:   return "\(Int(seconds / 86_400))d"
        default:           return "\(Int(seconds / 604_800))w"
        }
    }

    /// Parse a Postgres/ISO-8601 timestamp, tolerating presence or absence of fractional seconds.
    private static func parseISO(_ raw: String) -> Date? {
        isoFractional.date(from: raw) ?? isoPlain.date(from: raw)
    }

    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoPlain: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    private static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()
}
