import SwiftUI

/// Phase 2 renders the body; Phase 4 adds author attribution + author-reveal.
struct ReplyRowView: View {
    let reply: Reply
    let isOwner: Bool
    var onOwnerPrivatize: () -> Void

    var body: some View {
        Text(reply.body)
            .swipeActions(edge: .trailing) {
                if isOwner {
                    Button("Hide", role: .destructive, action: onOwnerPrivatize)
                }
            }
    }
}
