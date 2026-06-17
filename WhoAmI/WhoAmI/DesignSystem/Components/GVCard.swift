import SwiftUI

// =============================================================================
// GVCard — the base surface container.
//
// Port of design_system/components/surfaces/Card.jsx. Soft rounding
// (Theme.Radius.xl = 28), warm 1px border (Theme.border) over Theme.surface,
// with optional elevation. Most product surfaces compose from this primitive.
//
// React contract used elevation strings none/sm/md/lg and padding strings
// none/sm/lg. The Swift contract pins the nested enum to flat/low/mid/high and
// takes padding as a raw CGFloat (default Theme.Space.x6 = 20), so the
// elevation cases map straight onto the shadow ladder:
//   flat → none, low → shadowSm, mid → shadowMd, high → shadowLg.
//
// `interactive` in the web build lifts the card -2px and bumps it to shadowMd
// on hover (for tappable cards). On iOS that becomes press feedback: while the
// card is held it lifts, scales slightly, and gains the heavier shadow — the
// same affordance, expressed for touch.
// =============================================================================

struct GVCard<Content: View>: View {

    enum Elevation {
        case flat, low, mid, high

        /// Resting shadow for the card. `flat` has none.
        var shadow: GVShadow? {
            switch self {
            case .flat: return nil
            case .low:  return Theme.shadowSm
            case .mid:  return Theme.shadowMd
            case .high: return Theme.shadowLg
            }
        }
    }

    private let elevation: Elevation
    private let padding: CGFloat
    private let interactive: Bool
    private let content: Content

    init(
        elevation: Elevation = .low,
        padding: CGFloat = Theme.Space.x6,
        interactive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.elevation = elevation
        self.padding = padding
        self.interactive = interactive
        self.content = content()
    }

    @State private var pressed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var radius: CGFloat { Theme.Radius.xl } // 28

    /// While interactive + pressed, swap the resting shadow for the heavier
    /// hover shadow (mirrors the web `shadow-md` on hover).
    private var activeShadow: GVShadow? {
        guard interactive, pressed else { return elevation.shadow }
        return Theme.shadowMd
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: shape)
            .overlay(shape.strokeBorder(Theme.border, lineWidth: 1))
            .clipShape(shape)
            .modifier(CardShadow(shadow: activeShadow))
            .scaleEffect(interactive && pressed ? 0.98 : 1)
            .offset(y: interactive && pressed ? -2 : 0)
            .animation(reduceMotion ? nil : Theme.Motion.easeOut, value: pressed)
            .contentShape(shape)
            .modifier(InteractivePress(enabled: interactive, pressed: $pressed))
    }
}

// MARK: - Helpers

/// Applies an optional GVShadow without branching the view tree (keeps a stable
/// identity so the shadow can animate between resting and active states).
private struct CardShadow: ViewModifier {
    let shadow: GVShadow?

    func body(content: Content) -> some View {
        content.shadow(
            color: shadow?.color ?? .clear,
            radius: shadow?.radius ?? 0,
            x: 0,
            y: shadow?.y ?? 0
        )
    }
}

/// Tracks a "pressed" state for interactive cards using a zero-distance drag so
/// it reports touch-down/up without swallowing taps from inner controls.
private struct InteractivePress: ViewModifier {
    let enabled: Bool
    @Binding var pressed: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in if !pressed { pressed = true } }
                    .onEnded { _ in pressed = false }
            )
        } else {
            content
        }
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: Theme.Space.x6) {
            GVCard(elevation: .flat) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Flat").gvKicker()
                    Text("No shadow — sits flush on the surface.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                }
            }

            GVCard(elevation: .low) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Low · default").gvKicker()
                    Text("The everyday card surface.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                }
            }

            GVCard(elevation: .mid) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Mid").gvKicker()
                    Text("A little more lift for grouped content.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                }
            }

            GVCard(elevation: .high, interactive: true) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("High · interactive").gvKicker(Theme.primary)
                    Text("Press and hold — it lifts.")
                        .font(Theme.title)
                        .foregroundStyle(Theme.text)
                }
            }

            GVCard(elevation: .low, padding: Theme.Space.x3) {
                Text("Tight padding")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
            }
        }
        .padding(Theme.gutter)
    }
    .background(Theme.bg)
}
