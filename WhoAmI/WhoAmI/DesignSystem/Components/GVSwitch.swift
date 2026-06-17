import SwiftUI

/// Grapevine Switch — the opt-in toggle.
///
/// Ported from the design-system `Switch` (forms/Switch.jsx). The signature
/// use is the global "I'm down for spicy prompts" setting, so the ON track is
/// tintable. The web component exposed a `tone` prop ("primary" | "intrigue" |
/// "spicy" | "wholesome"); in SwiftUI that collapses into a single `tint`
/// `Color` so callers can pass `Theme.primary` (default), `Theme.intrigue`,
/// `Tone.spicy.color`, `Tone.wholesome.color`, etc.
///
/// Geometry matches the source 1:1: a 52×32 pill track, a 26×26 white thumb
/// inset 3pt, sliding from x:3 (off) to x:23 (on). The track background eases
/// on toggle; the thumb travels on the brand spring.
struct GVSwitch: View {
    @Binding var isOn: Bool
    var tint: Color = Theme.primary

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: Geometry (from Switch.jsx)
    private let trackWidth: CGFloat = 52
    private let trackHeight: CGFloat = 32
    private let thumbSize: CGFloat = 26
    private let inset: CGFloat = 3

    init(isOn: Binding<Bool>, tint: Color = Theme.primary) {
        self._isOn = isOn
        self.tint = tint
    }

    private var trackColor: Color {
        isOn ? tint : Theme.borderStrong
    }

    /// Leading offset of the thumb: 3 when off, 23 when on (52 − 26 − 3).
    private var thumbX: CGFloat {
        isOn ? trackWidth - thumbSize - inset : inset
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(trackColor)
                    .frame(width: trackWidth, height: trackHeight)

                Circle()
                    .fill(Color.white)
                    .frame(width: thumbSize, height: thumbSize)
                    // boxShadow: 0 2px 6px rgba(0,0,0,0.25)
                    .shadow(color: Color.black.opacity(0.25), radius: 3, x: 0, y: 2)
                    .offset(x: thumbX, y: 0)
            }
            .frame(width: trackWidth, height: trackHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        // background eases on dur-base/ease-out; thumb travels on the spring.
        .animation(reduceMotion ? nil : Theme.Motion.easeOut, value: isOn)
        .animation(reduceMotion ? nil : Theme.Motion.spring, value: thumbX)
        .accessibilityElement()
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
        .accessibilityAction { toggle() }
    }

    private func toggle() {
        guard isEnabled else { return }
        isOn.toggle()
    }
}

// MARK: - Preview

#Preview("GVSwitch") {
    struct Demo: View {
        @State private var spicy = true
        @State private var notifications = false
        @State private var wholesome = true
        @State private var intrigue = false
        @State private var disabledOn = true

        var body: some View {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                row("Spicy prompts", isOn: $spicy, tint: Tone.spicy.color)
                row("Notifications", isOn: $notifications, tint: Theme.primary)
                row("Wholesome only", isOn: $wholesome, tint: Tone.wholesome.color)
                row("Intrigue", isOn: $intrigue, tint: Theme.intrigue)

                HStack {
                    Text("Disabled (locked on)")
                        .font(Theme.body)
                        .foregroundStyle(Theme.text)
                    Spacer()
                    GVSwitch(isOn: $disabledOn, tint: Theme.primary)
                        .disabled(true)
                }
            }
            .padding(Theme.Space.x6)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.bg)
        }

        @ViewBuilder
        private func row(_ title: String, isOn: Binding<Bool>, tint: Color) -> some View {
            HStack {
                Text(title)
                    .font(Theme.body)
                    .foregroundStyle(Theme.text)
                Spacer()
                GVSwitch(isOn: isOn, tint: tint)
            }
        }
    }
    return Demo()
}
