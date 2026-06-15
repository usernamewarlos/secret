import SwiftUI

/// An attributed public reply. The owner can hide (privatize) it; only the author can ever
/// reveal it again (handled in the author's "Your reply" section).
struct ReplyRowView: View {
    let authorName: String
    let reply: Reply
    let canHide: Bool
    var onHide: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(authorName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(reply.body)
        }
        .swipeActions(edge: .trailing) {
            if canHide {
                Button("Hide", role: .destructive, action: onHide)
            }
        }
    }
}
