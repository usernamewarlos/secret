import SwiftUI

/// Grapevine graduation progress ring — the blind-accumulation status.
///
/// Shows `count / threshold` as a ring + mono count. While accumulating the
/// ring + text read **tangerine** (`Theme.primary`). The moment
/// `count >= threshold` it flips to **grape** (`Theme.intrigue`) and swaps the
/// inner count for an open lock — the "graduated, gist is ready 👀" state.
///
/// Pre-graduation this is the ONLY thing anyone sees. `threshold` is the
/// adaptive value `clamp(ceil(0.5 × repliers), 3, 10)` from the PRD — it is
/// passed in, never hardcoded here.
struct GVCounter: View {
    enum Size {
        case sm, md, lg

        /// Outer diameter of the ring.
        var dim: CGFloat {
            switch self {
            case .sm: return 44
            case .md: return 60
            case .lg: return 84
            }
        }

        /// Ring stroke width.
        var stroke: CGFloat {
            switch self {
            case .sm: return 4
            case .md: return 5
            case .lg: return 6
            }
        }
    }

    let count: Int
    let threshold: Int
    var size: Size = .md
    var showLabel: Bool = true

    init(count: Int, threshold: Int, size: Size = .md, showLabel: Bool = true) {
        self.count = count
        self.threshold = threshold
        self.size = size
        self.showLabel = showLabel
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Derived state

    private var graduated: Bool { count >= threshold }

    private var pct: CGFloat {
        guard threshold > 0 else { return 0 }
        return min(1, CGFloat(count) / CGFloat(threshold))
    }

    private var remaining: Int { max(0, threshold - count) }

    /// Tangerine while accumulating, grape once graduated.
    private var accent: Color { graduated ? Theme.intrigue : Theme.primary }

    // MARK: - Body

    var body: some View {
        HStack(spacing: Theme.Space.x4) {
            ring
            if showLabel { label }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(graduated
            ? "Graduated. Gist is ready."
            : "Accumulating. \(count) of \(threshold) replies, needs \(remaining) more.")
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            // Track
            Circle()
                .stroke(Theme.surface2, lineWidth: size.stroke)

            // Progress arc — starts at 12 o'clock, sweeps clockwise.
            Circle()
                .trim(from: 0, to: pct)
                .stroke(accent, style: StrokeStyle(lineWidth: size.stroke, lineCap: .round))
                .rotationEffect(.degrees(-90))

            // Inner content disc
            inner
        }
        .frame(width: size.dim, height: size.dim)
        .animation(reduceMotion ? nil : Theme.Motion.easeOut, value: pct)
        .animation(reduceMotion ? nil : Theme.Motion.easeOut, value: graduated)
    }

    @ViewBuilder
    private var inner: some View {
        if graduated {
            Image(systemName: "lock.open.fill")
                .font(.system(size: size.dim * 0.4, weight: .bold))
                .foregroundStyle(accent)
                .transition(.scale.combined(with: .opacity))
        } else {
            HStack(spacing: 0) {
                Text("\(count)")
                    .foregroundStyle(Theme.text)
                Text("/\(threshold)")
                    .foregroundStyle(Theme.textFaint)
            }
            .font(BrandFont.mono(size.dim * 0.26, .bold))
            .tracking(0.4)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, size.stroke)
        }
    }

    // MARK: - Label

    private var label: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x1) {
            Text(graduated ? "Graduated" : "Accumulating")
                .gvKicker(graduated ? Theme.intrigue : Theme.textMuted)

            Text(graduated
                ? "Gist is ready 👀"
                : remaining == 1 ? "needs 1 more reply" : "needs \(remaining) more replies")
                .font(BrandFont.hanken(14, .semibold))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Theme.Space.x7) {
        GVCounter(count: 3, threshold: 10, size: .sm)
        GVCounter(count: 8, threshold: 10, size: .md)
        GVCounter(count: 10, threshold: 10, size: .lg)
        GVCounter(count: 5, threshold: 7, size: .md, showLabel: false)
    }
    .padding(Theme.Space.x8)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .background(Theme.bg)
}
