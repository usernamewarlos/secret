import SwiftUI

// =============================================================================
// Grapevine — ReplyBubble
//
// One public, attributed reply beneath a gist. People sign their roasts, so we
// always show the author + body. The owner can `onPrivatize` to bury a reply
// (public → private) — they can never delete it or reveal a private one.
//
// SwiftUI port of design_system/components/surfaces/ReplyBubble.jsx
//   • flex row, 11pt gap, GVAvatar (md) on the leading edge
//   • header: bold name (sans 14) + mono relative time (faint 11) + optional
//     right-aligned "PRIVATIZE" control (mono uppercase, eye-slash glyph)
//   • body: surface-2 fill, asymmetric radius (sharp top-leading corner that
//     points back at the avatar), generous line height
// =============================================================================

struct ReplyBubble: View {
    private let name: String
    private let text: String
    private let time: String?
    private let canPrivatize: Bool
    private let onPrivatize: (() -> Void)?

    init(
        name: String,
        body: String,
        time: String? = nil,
        canPrivatize: Bool = false,
        onPrivatize: (() -> Void)? = nil
    ) {
        self.name = name
        self.text = body
        self.time = time
        self.canPrivatize = canPrivatize
        self.onPrivatize = onPrivatize
    }

    var body: some View {
        HStack(alignment: .top, spacing: 11) {
            GVAvatar(name: name, size: .md)

            VStack(alignment: .leading, spacing: 5) {
                header
                bubble
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Header (name · time · privatize)

    private var header: some View {
        HStack(spacing: Theme.Space.x3) {
            Text(name)
                .font(BrandFont.hanken(14, .bold))
                .foregroundStyle(Theme.text)

            if let time {
                Text(time)
                    .font(BrandFont.mono(11, .bold))
                    .foregroundStyle(Theme.textFaint)
            }

            if canPrivatize {
                Spacer(minLength: Theme.Space.x3)
                PrivatizeButton(action: onPrivatize)
            }
        }
    }

    // MARK: - Reply body

    private var bubble: some View {
        Text(text)
            .font(BrandFont.hanken(16, .regular))
            .foregroundStyle(Theme.text)
            .lineSpacing(16 * 0.5)                       // line-height ~1.5
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .background(
                BubbleShape()
                    .fill(Theme.surface2)
            )
    }
}

// =============================================================================
// Privatize control — mono UPPERCASE "PRIVATIZE" with eye-slash glyph.
// =============================================================================

private struct PrivatizeButton: View {
    let action: (() -> Void)?
    @State private var pressed = false

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "eye.slash.fill")        // ph-eye-slash
                    .font(.system(size: 13, weight: .bold))
                Text("Privatize")
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.66)                        // letter-spacing 0.06em
                    .textCase(.uppercase)
            }
            .foregroundStyle(Theme.textMuted)
            .contentShape(Rectangle())
            .scaleEffect(pressed ? 0.9 : 1)
            .animation(Theme.Motion.spring, value: pressed)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Privatize reply")
        ._onPressGesture { pressed = $0 }
    }
}

// =============================================================================
// Bubble shape — rounded on three corners, sharp (4pt) top-leading corner so
// the bubble reads as anchored to the avatar to its left.
// =============================================================================

private struct BubbleShape: Shape {
    func path(in rect: CGRect) -> Path {
        let big = Theme.Radius.lg     // 20
        let small: CGFloat = 4
        return Path(
            roundedRect: rect,
            cornerRadii: RectangleCornerRadii(
                topLeading: small,
                bottomLeading: big,
                bottomTrailing: big,
                topTrailing: big
            )
        )
    }
}

// =============================================================================
// Press-tracking helper (kept private to avoid colliding with siblings).
// =============================================================================

private extension View {
    func _onPressGesture(_ changed: @escaping (Bool) -> Void) -> some View {
        simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in changed(true) }
                .onEnded { _ in changed(false) }
        )
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.x6) {
            ReplyBubble(
                name: "Mara",
                body: "Okay but this is the most accurate thing anyone has said about him in years.",
                time: "2h"
            )

            ReplyBubble(
                name: "Devon Okafor",
                body: "I cannot stress enough how true this is. Filing it away for the group chat.",
                time: "5h",
                canPrivatize: true,
                onPrivatize: {}
            )

            ReplyBubble(
                name: "J",
                body: "no notes."
            )
        }
        .padding(Theme.gutter)
    }
    .background(Theme.bg)
}
