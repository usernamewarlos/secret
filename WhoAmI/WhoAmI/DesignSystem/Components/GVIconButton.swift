import SwiftUI

// =============================================================================
// GVIconButton — Grapevine's circular, icon-only control.
//
// SwiftUI port of design_system/components/forms/IconButton.jsx.
//
// A round icon button used for nav bars, share, settings, and dismiss. It
// always keeps the 44pt minimum tap target even when the visual circle is
// smaller (sm = 36pt visual). The `glass` variant is for overlays on top of
// imagery (e.g. a gist share-card) — translucent fill + material blur.
//
// Variants:  ghost · surface · primary · intrigue · glass
// Sizes:     sm (36 / icon 18) · md (44 / icon 22) · lg (52 / icon 26)
// Press:     scales to 0.9 (icon-button feel), respects reduced motion.
// =============================================================================

struct GVIconButton: View {

    // MARK: Nested types

    enum Variant {
        case ghost, surface, primary, intrigue, glass
    }

    enum Size {
        case sm, md, lg

        /// Diameter of the visible circle (px in the source).
        var dim: CGFloat {
            switch self {
            case .sm: return Theme.controlSm   // 36
            case .md: return Theme.tapMin       // 44
            case .lg: return 52
            }
        }

        /// Glyph point size.
        var iconSize: CGFloat {
            switch self {
            case .sm: return 18
            case .md: return 22
            case .lg: return 26
            }
        }
    }

    // MARK: Stored properties

    let icon: String                // SF Symbol name
    var variant: Variant = .ghost
    var size: Size = .md
    let accessibilityLabel: String
    let action: () -> Void

    init(
        icon: String,
        variant: Variant = .ghost,
        size: Size = .md,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.variant = variant
        self.size = size
        self.accessibilityLabel = accessibilityLabel
        self.action = action
    }

    // MARK: Body

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .foregroundStyle(foreground)
                // Center the glyph in the visible circle…
                .frame(width: size.dim, height: size.dim)
                .background(background)
                .overlay(
                    Circle().strokeBorder(borderColor, lineWidth: 1)
                )
                .clipShape(Circle())
                // …then guarantee the 44pt minimum tap target around it.
                .frame(width: max(size.dim, Theme.tapMin),
                       height: max(size.dim, Theme.tapMin))
                .contentShape(Circle())
        }
        .buttonStyle(GVIconButtonStyle())
        .accessibilityLabel(Text(accessibilityLabel))
    }

    // MARK: Variant styling

    private var foreground: Color {
        switch variant {
        case .ghost, .surface, .glass: return Theme.text
        case .primary:                 return Theme.onPrimary
        case .intrigue:                return Theme.onIntrigue
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .ghost:
            Color.clear
        case .surface:
            Theme.surface
        case .primary:
            Theme.primary
        case .intrigue:
            Theme.intrigue
        case .glass:
            // No dedicated glass token in the foundation — approximate the
            // overlay look with a material blur under a faint surface tint.
            Theme.surface.opacity(0.55)
                .background(.ultraThinMaterial)
        }
    }

    private var borderColor: Color {
        switch variant {
        case .ghost, .primary, .intrigue: return .clear
        case .surface:                    return Theme.border
        case .glass:                      return Theme.borderStrong
        }
    }
}

// =============================================================================
// Press feedback — icon buttons scale to 0.9 (vs 0.96 for text buttons),
// and dim to 0.4 when disabled, matching the source's transform/opacity.
// =============================================================================

private struct GVIconButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed
        return configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(pressed && !reduceMotion ? 0.9 : 1)
            .animation(reduceMotion ? nil : Theme.Motion.spring, value: pressed)
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    VStack(spacing: Theme.Space.x7) {
        HStack(spacing: Theme.Space.x5) {
            GVIconButton(icon: "square.and.arrow.up",
                         variant: .ghost,
                         accessibilityLabel: "Share") {}
            GVIconButton(icon: "gearshape.fill",
                         variant: .surface,
                         accessibilityLabel: "Settings") {}
            GVIconButton(icon: "paperplane.fill",
                         variant: .primary,
                         accessibilityLabel: "Send") {}
            GVIconButton(icon: "lock.fill",
                         variant: .intrigue,
                         accessibilityLabel: "Lock") {}
        }

        HStack(spacing: Theme.Space.x5) {
            GVIconButton(icon: "xmark",
                         variant: .ghost,
                         size: .sm,
                         accessibilityLabel: "Dismiss") {}
            GVIconButton(icon: "chevron.right",
                         variant: .surface,
                         size: .md,
                         accessibilityLabel: "Next") {}
            GVIconButton(icon: "plus",
                         variant: .primary,
                         size: .lg,
                         accessibilityLabel: "Add") {}
        }

        // Glass variant over imagery.
        ZStack {
            LinearGradient(colors: [Theme.Grape.s700, Theme.Tangerine.s500],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
                .frame(height: 120)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.lg))
            HStack(spacing: Theme.Space.x5) {
                GVIconButton(icon: "square.and.arrow.up",
                             variant: .glass,
                             accessibilityLabel: "Share gist") {}
                GVIconButton(icon: "heart.fill",
                             variant: .glass,
                             size: .lg,
                             accessibilityLabel: "Like") {}
            }
        }
        .padding(.horizontal, Theme.gutter)

        GVIconButton(icon: "trash",
                     variant: .surface,
                     accessibilityLabel: "Delete") {}
            .disabled(true)
    }
    .padding(Theme.Space.x8)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Theme.bg)
}
