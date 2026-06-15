import SwiftUI

/// The "then vs now" timeline — every gist version, oldest first (docs/PRODUCT.md §6.6).
struct GistEvolutionView: View {
    let postId: UUID

    @Environment(AppContainer.self) private var container
    @State private var versions: [GistVersion] = []
    @State private var loading = true

    var body: some View {
        List {
            if versions.isEmpty && !loading {
                Text("No history yet — the gist generates once this post graduates.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(Array(versions.enumerated()), id: \.element.id) { index, version in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(index == versions.count - 1 ? "Now" : "v\(index + 1)")
                            .font(.caption.weight(.bold))
                        Spacer()
                        Text(Self.day(from: version.createdAt))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    if let verdict = version.verdict {
                        Text(verdict).font(.headline)
                    }
                    Text(version.body).font(.subheadline)
                    Text("\(version.replyCountAtGeneration) replies")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("How you've changed")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            versions = (try? await container.gists.versions(postId: postId)) ?? []
            loading = false
        }
    }

    /// createdAt is an ISO timestamp string; show just the date.
    private static func day(from iso: String?) -> String {
        guard let iso, iso.count >= 10 else { return "" }
        return String(iso.prefix(10))
    }
}
