import SwiftUI

/// Used both as the "You" tab (ownerId == nil) and pushed for someone else's profile.
/// Does NOT wrap itself in a NavigationStack — the enclosing context provides one.
///
/// The crowd-authored portrait: a ringed XL avatar + name header (with a Settings
/// gear for the owner), a hero `GistCard` of who you are *right now*, then the living
/// archive — graduated prompts as mini cards (open-lock + reply/private counts) and
/// accumulating prompts as blind `GVCounter` rings. One `profile_feed` call backs it.
struct ProfileView: View {
    var ownerId: UUID? = nil
    var title: String? = nil

    @Environment(AppContainer.self) private var container
    @State private var vm: ProfileViewModel?
    @State private var showSettings = false

    private var isOwner: Bool { ownerId == nil }

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(isPresented: $showSettings) { SettingsView() }
        .onAppear {
            if vm == nil {
                let model = ProfileViewModel(
                    ownerId: ownerId,
                    titleFallback: title,
                    profile: container.profile,
                    auth: container.auth
                )
                vm = model
                Task { await model.load() }
            }
        }
        .refreshable { await vm?.load() }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: ProfileViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x7) {
                header(vm)

                if let hero = vm.heroPost, let verdict = hero.verdict {
                    heroGist(verdict, hero: hero)
                }

                archive(vm)

                if let error = vm.error {
                    Text(error)
                        .font(Theme.body)
                        .foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x6)
            .padding(.bottom, Theme.Space.x10)
        }
        .background(Theme.bg)
    }

    // MARK: - Header (avatar + name + owner gear)

    @ViewBuilder
    private func header(_ vm: ProfileViewModel) -> some View {
        HStack(spacing: Theme.Space.x4) {
            GVAvatar(name: vm.displayName, imageURL: vm.photoURL, size: .xl, ring: true)

            VStack(alignment: .leading, spacing: Theme.Space.x1) {
                Text(vm.displayName)
                    .font(Theme.display)
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(vm.handleLine)
                    .font(BrandFont.mono(12, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.x3)

            if isOwner {
                GVIconButton(icon: "gearshape.fill", variant: .surface, accessibilityLabel: "Settings") {
                    showSettings = true
                }
            }
        }
    }

    // MARK: - Hero gist

    @ViewBuilder
    private func heroGist(_ verdict: String, hero: ProfileFeed.Post) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            Text("Who you are right now").gvKicker()
            GistCard(
                gist: verdict,
                prompt: hero.promptText,
                replyCount: hero.count,
                surface: .ink,
                size: .sm
            )
            if hero.stale == true { staleTag }
        }
    }

    // MARK: - Archive

    @ViewBuilder
    private func archive(_ vm: ProfileViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            HStack(spacing: Theme.Space.x3) {
                Text("Your archive")
                    .font(Theme.heading)
                    .foregroundStyle(Theme.text)
                Text("\(vm.posts.count) prompt\(vm.posts.count == 1 ? "" : "s")")
                    .font(BrandFont.mono(11, .bold))
                    .foregroundStyle(Theme.textFaint)
            }

            if vm.posts.isEmpty && !vm.loading {
                emptyState
            } else {
                VStack(spacing: Theme.Space.x4) {
                    ForEach(vm.posts) { post in
                        archiveRow(post)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func archiveRow(_ post: ProfileFeed.Post) -> some View {
        let tone = Tone(spice: post.spiceLevel)

        switch post.status {
        case .graduated:
            NavigationLink {
                PostDetailView(postId: post.id, promptText: post.promptText, isOwner: isOwner)
            } label: {
                graduatedCard(post, tone: tone)
            }
            .buttonStyle(.plain)

        case .accumulating:
            accumulatingCard(post, tone: tone)

        case .expired:
            expiredCard(post, tone: tone)
        }
    }

    /// Graduated → unlocked mini card: tone tag, open-lock, prompt, gist line, counts.
    private func graduatedCard(_ post: ProfileFeed.Post, tone: Tone) -> some View {
        GVCard(padding: Theme.Space.x5, interactive: true) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    ToneTag(tone, size: .sm)
                    Spacer(minLength: 0)
                    Image(systemName: "lock.open.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.intrigue)
                }
                .padding(.bottom, Theme.Space.x3)

                Text(post.promptText)
                    .font(BrandFont.hanken(13, .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.bottom, Theme.Space.x2)

                Text(post.verdict ?? "Your gist is ready.")
                    .font(BrandFont.hanken(19, .heavy))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                if post.stale == true {
                    staleTag.padding(.top, Theme.Space.x3)
                }

                countsLine(total: post.count, privateCount: post.privateCount)
                    .padding(.top, Theme.Space.x4)
            }
        }
    }

    /// Accumulating → blind counter ring (the only pre-graduation signal).
    private func accumulatingCard(_ post: ProfileFeed.Post, tone: Tone) -> some View {
        GVCard(padding: Theme.Space.x5) {
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                ToneTag(tone, size: .sm)
                Text(post.promptText)
                    .font(BrandFont.hanken(14, .semibold))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                GVCounter(count: post.count, threshold: post.threshold, size: .md)
            }
        }
    }

    /// Expired → muted, no counts.
    private func expiredCard(_ post: ProfileFeed.Post, tone: Tone) -> some View {
        GVCard(padding: Theme.Space.x5) {
            VStack(alignment: .leading, spacing: Theme.Space.x3) {
                ToneTag(tone, size: .sm)
                Text(post.promptText)
                    .font(BrandFont.hanken(14, .semibold))
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Expired").gvKicker(Theme.textFaint)
            }
        }
    }

    /// "12 REPLIES · 🔒 2 PRIVATE" — mono, faint, lock-tinted private segment.
    @ViewBuilder
    private func countsLine(total: Int, privateCount: Int) -> some View {
        HStack(spacing: Theme.Space.x4) {
            Text("\(total) REPL\(total == 1 ? "Y" : "IES")")
                .font(BrandFont.mono(11, .bold))
                .foregroundStyle(Theme.textFaint)

            if privateCount > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("\(privateCount) PRIVATE")
                        .font(BrandFont.mono(11, .bold))
                }
                .foregroundStyle(Theme.lock)
            }
        }
    }

    /// "BASED ON FEWER VOICES NOW" — shown when a revoke thinned a graduated post below its
    /// voice floor, so the portrait reads with the right context on the most-viewed surface.
    private var staleTag: some View {
        HStack(spacing: 5) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 10, weight: .bold))
            Text("Based on fewer voices now")
                .font(BrandFont.mono(10, .bold))
                .tracking(0.6)
                .textCase(.uppercase)
        }
        .foregroundStyle(Theme.warning)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        GVCard {
            Text(isOwner
                 ? "No posts yet. Your profile fills in as friends answer prompts about you."
                 : "Nothing here yet.")
                .font(Theme.body)
                .foregroundStyle(Theme.textMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
