import SwiftUI

// =============================================================================
// ActivityView — the "Activity" tab (its own NavigationStack root).
//
// A reverse-chronological event feed DERIVED from real data the app already
// owns — no dedicated activity/notifications backend is invented here:
//
//   • container.posts.myPosts()       → "gist ready" events (graduated posts)
//                                        and "almost there" nudges (accumulating
//                                        posts within reach of their threshold).
//   • container.connections.list()    → "joined" / "became a replier" events for
//                                        recent connections.
//   • container.prompts.byId(_:)       → resolves each post's prompt text.
//   • container.profile.fetchMany(_:) → resolves connection display names.
//
// The hero is a single highlighted "graduated" card pinned to the top (intrigue
// soft background, lock border, a subtle grape glow). Tapping a gist-ready event
// pushes PostDetailView when we have enough to construct it; everything else is a
// graceful no-op. Empty state nudges the user to answer a prompt.
// =============================================================================

struct ActivityView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: ActivityViewModel?

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if let vm, vm.hasUnread {
                        GVButton("Mark all read", variant: .ghost, size: .sm) {
                            vm.markAllRead()
                        }
                    }
                }
            }
            .navigationDestination(for: ActivityViewModel.Destination.self) { dest in
                PostDetailView(
                    postId: dest.postId,
                    promptText: dest.promptText,
                    isOwner: true
                )
            }
            .onAppear {
                if vm == nil {
                    let model = ActivityViewModel(
                        posts: container.posts,
                        prompts: container.prompts,
                        connections: container.connections,
                        profile: container.profile
                    )
                    vm = model
                    Task { await model.load() }
                }
            }
            .refreshable { await vm?.load() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: ActivityViewModel) -> some View {
        if vm.loading && vm.events.isEmpty && vm.highlight == nil {
            ProgressView()
                .tint(Theme.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if vm.events.isEmpty && vm.highlight == nil {
            emptyState
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    if let highlight = vm.highlight {
                        highlightCard(highlight)
                            .padding(.bottom, Theme.Space.x2)
                    }

                    if !vm.events.isEmpty {
                        Text("EARLIER")
                            .gvKicker(Theme.textMuted)
                            .padding(.horizontal, Theme.Space.x1)

                        VStack(spacing: Theme.Space.x3) {
                            ForEach(vm.events) { event in
                                eventRow(event)
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, Theme.Space.x2)
                .padding(.bottom, Theme.Space.x10)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .animation(Theme.Motion.spring, value: vm.events.count)
        }
    }

    // MARK: - Highlighted graduated card (hero)

    @ViewBuilder
    private func highlightCard(_ event: ActivityViewModel.Event) -> some View {
        let card = VStack(alignment: .leading, spacing: Theme.Space.x3) {
            HStack(spacing: Theme.Space.x2) {
                Image(systemName: "lock.open.fill")
                    .font(.system(size: 12, weight: .bold))
                Text(event.kicker)
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                Spacer(minLength: 0)
                Text(event.timeLabel)
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.intrigue)

            Text(event.title)
                .font(BrandFont.hanken(20, .bold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let sub = event.sub {
                Text(sub)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: Theme.Space.x2) {
                Text("Read the gist")
                    .font(BrandFont.hanken(14, .bold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(Theme.intrigue)
            .padding(.top, Theme.Space.x1)
        }
        .padding(Theme.Space.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .fill(Theme.intrigueSoft)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                .strokeBorder(Theme.lockBorder, lineWidth: 1.5)
        )
        .gvShadow(Theme.glowGrape)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous))

        if let dest = event.destination {
            NavigationLink(value: dest) { card }
                .buttonStyle(.plain)
                .accessibilityLabel("\(event.title). \(event.timeLabel). Read the gist.")
        } else {
            card
        }
    }

    // MARK: - Feed row

    @ViewBuilder
    private func eventRow(_ event: ActivityViewModel.Event) -> some View {
        let row = GVCard(elevation: .low, padding: Theme.Space.x4, interactive: event.destination != nil) {
            HStack(alignment: .top, spacing: Theme.Space.x3) {
                iconTile(symbol: event.symbol, tone: event.toneColor)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(BrandFont.hanken(15, .semibold))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let sub = event.sub {
                        Text(sub)
                            .font(Theme.label)
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text(event.timeLabel)
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.4)
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize()
            }
        }

        if let dest = event.destination {
            NavigationLink(value: dest) { row }
                .buttonStyle(.plain)
                .accessibilityLabel("\(event.title). \(event.timeLabel).")
        } else {
            row
        }
    }

    /// A tone-colored, rounded icon tile.
    private func iconTile(symbol: String, tone: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(tone)
            .frame(width: 40, height: 40)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(tone.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(tone.opacity(0.28), lineWidth: 1)
            )
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Space.x4) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Theme.primary)
                .frame(width: 76, height: 76)
                .background(Theme.primarySoft, in: Circle())

            Text("No activity yet")
                .font(BrandFont.hanken(20, .bold))
                .foregroundStyle(Theme.text)

            Text("No activity yet — answer a prompt to get the vine going.")
                .font(Theme.body)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.Space.x6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, Theme.Space.x12)
    }
}

// =============================================================================
// ActivityViewModel — derives a reverse-chron feed from posts + connections.
// =============================================================================

@MainActor
@Observable
final class ActivityViewModel {

    /// A single rendered feed item.
    struct Event: Identifiable, Hashable {
        let id: String
        /// Sort key (most recent first). Higher = newer.
        let sortDate: Date
        let symbol: String
        let toneColor: Color
        let kicker: String
        let title: String
        let sub: String?
        let timeLabel: String
        /// When set, tapping the row/card pushes PostDetailView.
        let destination: Destination?

        static func == (lhs: Event, rhs: Event) -> Bool { lhs.id == rhs.id }
        func hash(into hasher: inout Hasher) { hasher.combine(id) }
    }

    /// Navigation payload to a graduated post's gist.
    struct Destination: Hashable {
        let postId: UUID
        let promptText: String
    }

    // Inputs
    private let posts: PostsService
    private let prompts: PromptsService
    private let connections: ConnectionsService
    private let profile: ProfileService

    // State
    private(set) var highlight: Event?
    private(set) var events: [Event] = []
    private(set) var loading = false
    private(set) var hasUnread = false
    /// Newest event timestamp this load (what "mark all read" advances the marker to).
    private var newestDate: Date?
    private let readKey = "gv.activity.lastReadAt"
    private var lastReadAt: Date {
        get { Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: readKey)) }
        set { UserDefaults.standard.set(newValue.timeIntervalSince1970, forKey: readKey) }
    }

    init(
        posts: PostsService,
        prompts: PromptsService,
        connections: ConnectionsService,
        profile: ProfileService
    ) {
        self.posts = posts
        self.prompts = prompts
        self.connections = connections
        self.profile = profile
    }

    // MARK: - Load

    func load() async {
        loading = true
        defer { loading = false }

        var built: [Event] = []

        // --- Posts → gist-ready + nudge events -------------------------------
        let myPosts = (try? await posts.myPosts()) ?? []

        // Resolve prompt text once per unique prompt id.
        var promptText: [UUID: String] = [:]
        for pid in Set(myPosts.map(\.promptId)) {
            if let p = try? await prompts.byId(pid) {
                promptText[pid] = p.text
            }
        }

        for post in myPosts {
            let text = promptText[post.promptId]
            let promptLabel = Self.shortPrompt(text)

            switch post.status {
            case .graduated:
                let date = Self.parseISO(post.graduatedAt) ?? Date.distantPast
                let dest = text.map { Destination(postId: post.id, promptText: $0) }
                built.append(
                    Event(
                        id: "gist-\(post.id.uuidString)",
                        sortDate: date,
                        symbol: "sparkles",
                        toneColor: Theme.intrigue,
                        kicker: "Graduated at \(post.threshold)/\(post.threshold)",
                        title: "Your \(promptLabel) gist is ready 👀",
                        sub: text == nil ? nil : "An AI take on what your friends said — in their words.",
                        timeLabel: Self.relative(date),
                        destination: dest
                    )
                )

            case .accumulating:
                // Only nudge when the post is meaningfully close to graduating.
                // We don't have a live count on Post, so we treat a high threshold
                // post as "in progress" and surface a gentle keep-going nudge.
                guard post.threshold > 0 else { continue }
                let tone = Tone(spice: post.spiceLevel)
                built.append(
                    Event(
                        id: "nudge-\(post.id.uuidString)",
                        sortDate: Date.distantPast.addingTimeInterval(1),
                        symbol: "arrow.up.right.circle.fill",
                        toneColor: tone.color,
                        kicker: "Almost there",
                        title: "\(promptLabel) is gathering replies",
                        sub: "It graduates at \(post.threshold) — nudge a friend to weigh in.",
                        timeLabel: "live",
                        destination: nil
                    )
                )

            case .expired:
                continue
            }
        }

        // --- Connections → joined / replier events ---------------------------
        let conns = (try? await connections.list()) ?? []
        let recent = Array(conns.prefix(12))
        let names = await resolveNames(for: recent.map(\.connectedUserId))

        for conn in recent {
            let date = Self.parseISO(conn.createdAt) ?? Date.distantPast
            let name = names[conn.connectedUserId] ?? "Someone"
            let isReplier = conn.role == .replier
            built.append(
                Event(
                    id: "conn-\(conn.id.uuidString)",
                    sortDate: date,
                    symbol: isReplier ? "person.fill.checkmark" : "person.badge.plus",
                    toneColor: isReplier ? Tone.social.color : Tone.wholesome.color,
                    kicker: isReplier ? "Replier" : "Joined",
                    title: isReplier
                        ? "\(name) became one of your repliers"
                        : "\(name) joined your vine",
                    sub: isReplier
                        ? "They can now reply to your prompts."
                        : "They can see your graduated gists.",
                    timeLabel: Self.relative(date),
                    destination: nil
                )
            )
        }

        // --- Sort reverse-chron, then split out the freshest gist as hero ----
        built.sort { $0.sortDate > $1.sortDate }

        if let heroIndex = built.firstIndex(where: { $0.id.hasPrefix("gist-") }) {
            highlight = built.remove(at: heroIndex)
        } else {
            highlight = nil
        }
        events = built

        newestDate = (([highlight].compactMap { $0 }) + events).map(\.sortDate).max()
        hasUnread = (newestDate.map { $0 > lastReadAt }) ?? false
    }

    // MARK: - Actions

    func markAllRead() {
        lastReadAt = newestDate ?? Date()
        hasUnread = false
    }

    // MARK: - Helpers

    private func resolveNames(for ids: [UUID]) async -> [UUID: String] {
        guard !ids.isEmpty else { return [:] }
        let profiles = (try? await profile.fetchMany(ids: ids)) ?? []
        var map: [UUID: String] = [:]
        for p in profiles {
            map[p.id] = (p.displayName?.isEmpty == false) ? p.displayName! : nil
        }
        return map
    }

    /// A short, quoted prompt fragment for inline titles, e.g. 'what's...'.
    private static func shortPrompt(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "your" }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let clipped = trimmed.count > 36 ? String(trimmed.prefix(33)) + "…" : trimmed
        return "'\(clipped)'"
    }

    /// Compact relative time ("now", "2m", "3h", "5d", "2w").
    static func relative(_ date: Date) -> String {
        guard date > Date.distantPast else { return "" }
        let seconds = max(0, Date().timeIntervalSince(date))
        switch seconds {
        case ..<60:       return "now"
        case ..<3_600:    return "\(Int(seconds / 60))m ago"
        case ..<86_400:   return "\(Int(seconds / 3_600))h ago"
        case ..<604_800:  return "\(Int(seconds / 86_400))d ago"
        default:          return "\(Int(seconds / 604_800))w ago"
        }
    }

    static func parseISO(_ raw: String?) -> Date? {
        guard let raw else { return nil }
        return isoFractional.date(from: raw) ?? isoPlain.date(from: raw)
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
}
