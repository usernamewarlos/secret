import SwiftUI

/// Grapevine `LockChip` — the intrigue engine.
///
/// Renders a private reply as a *named but locked* item: you know exactly WHO
/// left it, but neither you nor the profile owner can ever read it (content is
/// author-only, forever). Naming the author is the sharp curiosity that drives
/// "what did you say??" conversations off-platform.
///
/// Reads as grape throughout (`Theme.lock*`). Names the author only — it never
/// renders or implies the hidden content.
///
/// - `.list`    — full row for a profile archive (avatar + lock badge + kicker).
/// - `.inline`  — compact mono pill for a reply stack ("Marcus · private").
struct LockChip: View {
    enum Variant {
        /// Full row on a profile archive.
        case list
        /// Compact pill in a reply stack.
        case inline
    }

    private let name: String
    private let variant: Variant

    init(name: String, variant: Variant = .list) {
        self.name = name
        self.variant = variant
    }

    var body: some View {
        switch variant {
        case .inline: inlineChip
        case .list:   listRow
        }
    }

    // MARK: - Inline pill

    private var inlineChip: some View {
        HStack(spacing: 7) {
            Image(systemName: "lock.fill")
                .font(.system(size: 13, weight: .bold))
            Text("\(name) · private")
                .font(BrandFont.mono(12, .bold))
        }
        .foregroundStyle(Theme.lock)
        .padding(.vertical, 5)
        .padding(.horizontal, Theme.Space.x4) // 12
        .background(
            Capsule(style: .continuous).fill(Theme.lockBg)
        )
        .overlay(
            Capsule(style: .continuous).strokeBorder(Theme.lockBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) left a private reply")
    }

    // MARK: - List row

    private var listRow: some View {
        HStack(spacing: Theme.Space.x4) { // 12
            avatarWithLockBadge

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(BrandFont.hanken(14, .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Text("LEFT A PRIVATE REPLY")
                    .font(BrandFont.mono(11, .bold))
                    .tracking(0.88) // ~0.08em of 11px
                    .foregroundStyle(Theme.lock)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.vertical, Theme.Space.x4) // 12
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(Theme.lockBg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(Theme.lockBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(name) left a private reply")
    }

    private var avatarWithLockBadge: some View {
        GVAvatar(name: name, size: .md)
            .overlay(alignment: .bottomTrailing) {
                ZStack {
                    Circle().fill(Theme.lock)
                    Circle().strokeBorder(Theme.surface, lineWidth: 2)
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 20, height: 20)
                .offset(x: 3, y: 3)
            }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.x5) {
            Text("LockChip")
                .gvKicker()

            LockChip(name: "Sarah")
            LockChip(name: "Marcus Whitfield-Greene")

            HStack(spacing: Theme.Space.x3) {
                LockChip(name: "Marcus", variant: .inline)
                LockChip(name: "Priya", variant: .inline)
            }
        }
        .padding(Theme.gutter)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .background(Theme.bg)
}
