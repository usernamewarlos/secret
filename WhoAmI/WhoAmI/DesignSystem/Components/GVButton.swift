import SwiftUI

// =============================================================================
// GVButton — the primary action control.
//
// Pill-shaped, bold label, brand glow on filled variants. Variants map to the
// brand poles: `primary` (tangerine — warmth/action), `intrigue` (grape — the
// locked/private side), plus `secondary` (outlined), `ghost` (bare), and
// `danger` (revoke/block).
//
// Ported from design_system/components/forms/Button.jsx. Consumes Theme tokens
// exclusively — no foundation types are redefined here.
// =============================================================================

struct GVButton: View {
    enum Variant { case primary, intrigue, secondary, ghost, danger }
    enum Size { case sm, md, lg }

    private let title: String
    private let variant: Variant
    private let size: Size
    private let full: Bool
    private let icon: String?
    private let trailingIcon: String?
    private let loading: Bool
    private let enabled: Bool
    private let action: () -> Void

    init(
        _ title: String,
        variant: Variant = .primary,
        size: Size = .md,
        full: Bool = false,
        icon: String? = nil,
        trailingIcon: String? = nil,
        loading: Bool = false,
        enabled: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.size = size
        self.full = full
        self.icon = icon
        self.trailingIcon = trailingIcon
        self.loading = loading
        self.enabled = enabled
        self.action = action
    }

    // disabled || loading both block interaction (matches JSX `disabled || loading`).
    private var isInteractive: Bool { enabled && !loading }

    var body: some View {
        Button(action: action) {
            content
        }
        .buttonStyle(
            PressStyle(
                variant: variant,
                size: size,
                full: full,
                enabled: enabled
            )
        )
        .disabled(!isInteractive)
        .accessibilityLabel(Text(title))
    }

    @ViewBuilder
    private var content: some View {
        HStack(spacing: 9) {
            if loading {
                SpinnerView(size: size.iconSize)
            } else {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .bold))
                }
                Text(title)
                    .font(BrandFont.hanken(size.fontSize, .bold))
                    .tracking(-0.01 * size.fontSize)
                    .lineLimit(1)
                if let trailingIcon {
                    Image(systemName: trailingIcon)
                        .font(.system(size: size.iconSize, weight: .bold))
                }
            }
        }
        .frame(maxWidth: full ? .infinity : nil)
        .frame(height: size.height)
        .padding(.horizontal, size.horizontalPadding)
    }
}

// MARK: - Size metrics

private extension GVButton.Size {
    // sm: control-h-sm (36), md: control-h-md (48), lg: control-h-lg (56)
    var height: CGFloat {
        switch self {
        case .sm: return Theme.controlSm
        case .md: return Theme.controlMd
        case .lg: return Theme.controlLg
        }
    }

    // padding "0 16px" / "0 22px" / "0 28px"
    var horizontalPadding: CGFloat {
        switch self {
        case .sm: return 16
        case .md: return 22
        case .lg: return 28
        }
    }

    // --text-sm / --text-base / --text-lg
    var fontSize: CGFloat {
        switch self {
        case .sm: return 14
        case .md: return 16
        case .lg: return 18
        }
    }

    // icon: 16 / 19 / 22
    var iconSize: CGFloat {
        switch self {
        case .sm: return 16
        case .md: return 19
        case .lg: return 22
        }
    }
}

// MARK: - Variant styling

private extension GVButton.Variant {
    var background: Color {
        switch self {
        case .primary:   return Theme.primary
        case .intrigue:  return Theme.intrigue
        case .secondary: return Theme.surface
        case .ghost:     return Color.clear
        case .danger:    return Theme.danger
        }
    }

    var foreground: Color {
        switch self {
        case .primary:   return Theme.onPrimary
        case .intrigue:  return Theme.onIntrigue
        case .secondary: return Theme.text
        case .ghost:     return Theme.text
        case .danger:    return Color.white
        }
    }

    // secondary: 1.5px solid border-strong; ghost: transparent; others: transparent.
    var borderColor: Color {
        switch self {
        case .secondary: return Theme.borderStrong
        default:         return Color.clear
        }
    }

    var borderWidth: CGFloat {
        switch self {
        case .secondary: return 1.5
        default:         return 1
        }
    }

    // primary → tangerine glow, intrigue → grape glow, others → none.
    var glow: GVShadow? {
        switch self {
        case .primary:  return Theme.glowTangerine
        case .intrigue: return Theme.glowGrape
        default:        return nil
        }
    }
}

// MARK: - Press style (scale 0.96, disabled opacity 0.45)

private struct PressStyle: ButtonStyle {
    let variant: GVButton.Variant
    let size: GVButton.Size
    let full: Bool
    let enabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && enabled
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)

        return configuration.label
            .foregroundStyle(variant.foreground)
            .background(variant.background, in: shape)
            .overlay {
                shape.strokeBorder(variant.borderColor, lineWidth: variant.borderWidth)
            }
            .modifier(GlowModifier(glow: enabled ? variant.glow : nil))
            .contentShape(shape)
            .opacity(enabled ? 1 : 0.45)
            .scaleEffect(pressed ? 0.96 : 1)
            .animation(reducedMotion ? nil : Theme.Motion.easeOut, value: pressed)
            .frame(maxWidth: full ? .infinity : nil)
    }
}

// Conditionally applies a brand glow only on filled, enabled variants.
private struct GlowModifier: ViewModifier {
    let glow: GVShadow?
    func body(content: Content) -> some View {
        if let glow {
            content.gvShadow(glow)
        } else {
            content
        }
    }
}

// MARK: - Inline spinner (mirrors the gv-spin keyframe)

private struct SpinnerView: View {
    let size: CGFloat
    @State private var spinning = false
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.75)
            .stroke(Color.currentLabel, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(
                reducedMotion ? nil : .linear(duration: 0.7).repeatForever(autoreverses: false),
                value: spinning
            )
            .onAppear { spinning = true }
    }
}

// `currentColor` stand-in: the spinner inherits the button's foreground via the
// surrounding `foregroundStyle`, so we tint with the primary content color.
private extension Color {
    static var currentLabel: Color { Color.primary }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(alignment: .leading, spacing: Theme.Space.x5) {
            GVButton("Send your reply", variant: .primary, size: .lg, full: true,
                     icon: "paperplane.fill") {}

            GVButton("Leave a private reply", variant: .intrigue,
                     icon: "lock.fill") {}

            HStack(spacing: Theme.Space.x4) {
                GVButton("Secondary", variant: .secondary) {}
                GVButton("Ghost", variant: .ghost) {}
            }

            GVButton("Revoke", variant: .danger, size: .sm,
                     trailingIcon: "xmark") {}

            GVButton("Unlocking…", variant: .primary, loading: true) {}

            GVButton("Disabled", variant: .primary, enabled: false) {}
        }
        .padding(Theme.gutter)
    }
    .background(Theme.bg)
}
