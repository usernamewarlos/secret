import SwiftUI

/// The "then vs now" timeline — every gist version, oldest first (docs/PRODUCT.md §6.6).
/// Restyled to the Grapevine "Gist evolution" handoff: a poster of the selected
/// version up top + a tappable vertical timeline that swaps which version is shown.
struct GistEvolutionView: View {
    let postId: UUID

    @Environment(AppContainer.self) private var container
    @State private var versions: [GistVersion] = []
    @State private var loading = true

    /// Which version is rendered in the poster. UI-only selection state; the
    /// version data itself comes straight from the VM/service. Defaults to the
    /// newest version once `versions` loads (see `.task`).
    @State private var selectedIndex = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                header

                if versions.isEmpty {
                    emptyState
                } else {
                    poster
                    timeline
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x2)
            .padding(.bottom, Theme.Space.x8)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("How you've evolved")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            versions = (try? await container.gists.versions(postId: postId)) ?? []
            // Open on the most recent version (versions are oldest-first).
            selectedIndex = max(0, versions.count - 1)
            loading = false
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x1) {
            Text("How you've evolved")
                .font(Theme.display)
                .foregroundStyle(Theme.text)
            Text("Then vs now — tap any version to bring it back.")
                .font(Theme.body)
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Selected poster

    @ViewBuilder
    private var poster: some View {
        let version = selectedVersion
        GistCard(
            gist: version.verdict ?? version.body,
            replyCount: version.replyCountAtGeneration,
            date: Self.day(from: version.createdAt),
            surface: .ink,
            size: .sm
        )
        .id(selectedIndex)
        .transition(.opacity)
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x2) {
            // "TIMELINE  V3 · 12 VOICES" kicker row.
            HStack(spacing: Theme.Space.x2) {
                Text("Timeline")
                    .gvKicker(Theme.textMuted)
                Text(monoLabel(for: selectedIndex))
                    .font(BrandFont.mono(10.5, .regular))
                    .tracking(0.5)
                    .foregroundStyle(Theme.textFaint)
            }

            VStack(spacing: Theme.Space.x0) {
                ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                    timelineRow(index: index, version: version)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timelineRow(index: Int, version: GistVersion) -> some View {
        let active = index == selectedIndex
        return Button {
            withAnimation(Theme.Motion.spring) { selectedIndex = index }
        } label: {
            HStack(spacing: Theme.Space.x3) {
                // Dot — primary fill + soft ring when active; hollow surface otherwise.
                Circle()
                    .fill(active ? Theme.primary : Theme.surface)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle().strokeBorder(
                            active ? Theme.primarySoft : Theme.borderStrong,
                            lineWidth: active ? 4 : 2
                        )
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(dateLabel(for: index, version: version))
                        .font(BrandFont.hanken(14.5, .bold))
                        .foregroundStyle(active ? Theme.text : Theme.textMuted)
                    Text(monoLabel(for: index))
                        .font(BrandFont.mono(10, .bold))
                        .tracking(1)
                        .foregroundStyle(Theme.textFaint)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, Theme.Space.x3)
            .padding(.vertical, Theme.Space.x2 + 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(active ? Theme.surface2 : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(active ? Theme.borderStrong : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        GVCard(elevation: .low) {
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text("No history yet")
                    .font(Theme.title)
                    .foregroundStyle(Theme.text)
                Text("The gist generates once this post graduates — then every new version lands here.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Derived values

    private var selectedVersion: GistVersion {
        let safe = min(max(selectedIndex, 0), max(versions.count - 1, 0))
        return versions[safe]
    }

    /// Display label for a timeline row: "Now" for the latest, otherwise the date.
    private func dateLabel(for index: Int, version: GistVersion) -> String {
        if index == versions.count - 1 { return "Now" }
        let day = Self.day(from: version.createdAt)
        return day.isEmpty ? "v\(index + 1)" : day
    }

    /// Mono caption: "V2 · 8 VOICES".
    private func monoLabel(for index: Int) -> String {
        guard versions.indices.contains(index) else { return "" }
        let voices = versions[index].replyCountAtGeneration
        let noun = voices == 1 ? "VOICE" : "VOICES"
        return "V\(index + 1) · \(voices) \(noun)"
    }

    /// createdAt is an ISO timestamp string; show just the date.
    private static func day(from iso: String?) -> String {
        guard let iso, iso.count >= 10 else { return "" }
        return String(iso.prefix(10))
    }
}
