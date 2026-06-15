import SwiftUI

struct PostRowView: View {
    let row: ProfileViewModel.Row
    let isOwner: Bool

    private var promptText: String { row.prompt?.text ?? "Prompt" }

    var body: some View {
        switch row.post.status {
        case .graduated:
            NavigationLink {
                PostDetailView(postId: row.post.id, promptText: promptText, isOwner: isOwner)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(promptText)
                    Text("Graduated · \(row.count) repl\(row.count == 1 ? "y" : "ies")")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case .accumulating:
            let remaining = max(0, row.post.threshold - row.count)
            VStack(alignment: .leading, spacing: 2) {
                Text(promptText)
                Text(remaining > 0
                     ? "needs \(remaining) more · \(row.count)/\(row.post.threshold)"
                     : "graduating…")
                    .font(.caption).foregroundStyle(.secondary)
            }
        case .expired:
            VStack(alignment: .leading, spacing: 2) {
                Text(promptText).foregroundStyle(.secondary)
                Text("expired").font(.caption).foregroundStyle(.tertiary)
            }
        }
    }
}
