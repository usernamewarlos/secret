import SwiftUI

/// Grapevine input — single-line text field or multiline reply composer.
///
/// Soft rounded, warm border, tangerine focus ring. Single-line fields are
/// pill-shaped at control-md height; multiline fields use the large radius and
/// grow with their content from `minHeight`. Pass `maxLength` to surface a live
/// mono character counter that flips to `danger` as it nears the cap (replies
/// cap around 280–500). `leadingIcon` (an SF Symbol name) only renders on the
/// single-line variant, matching the web source.
struct GVInput: View {
    private let placeholder: String
    @Binding private var text: String
    private let multiline: Bool
    private let minHeight: CGFloat
    private let maxLength: Int?
    private let leadingIcon: String?
    private let invalid: Bool

    @FocusState private var focused: Bool
    @Environment(\.isEnabled) private var isEnabled

    init(
        _ placeholder: String,
        text: Binding<String>,
        multiline: Bool = false,
        minHeight: CGFloat = 120,
        maxLength: Int? = nil,
        leadingIcon: String? = nil,
        invalid: Bool = false
    ) {
        self.placeholder = placeholder
        self._text = text
        self.multiline = multiline
        self.minHeight = minHeight
        self.maxLength = maxLength
        self.leadingIcon = leadingIcon
        self.invalid = invalid
    }

    // MARK: - Derived style

    private var count: Int { text.count }

    private var borderColor: Color {
        if invalid { return Theme.danger }
        if focused { return Theme.ring }
        return Theme.borderStrong
    }

    private var cornerRadius: CGFloat {
        multiline ? Theme.Radius.lg : Theme.Radius.pill
    }

    /// Leading inset for the text content. Mirrors the web field's `padding`
    /// (18 single-line / 16 multiline) plus the 46pt indent when a leading icon
    /// is shown on the single-line variant.
    private var leadingInset: CGFloat {
        if !multiline, leadingIcon != nil { return 46 }
        return multiline ? Theme.Space.x5 : 18
    }

    /// Counter flips to danger once within 10% of the cap, per the source.
    private func counterColor(_ max: Int) -> Color {
        count > Int(Double(max) * 0.9) ? Theme.danger : Theme.textFaint
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: multiline ? .topLeading : .leading) {
            field
            if !multiline, let leadingIcon {
                Image(systemName: leadingIcon)
                    .font(.system(size: 19))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.leading, 17)
                    .allowsHitTesting(false)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: multiline ? minHeight : Theme.controlMd, alignment: .topLeading)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .overlay(alignment: counterAlignment) { counter }
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.primarySoft, lineWidth: focused ? 4 : 0)
                .padding(-4)
                .allowsHitTesting(false)
        )
        .opacity(isEnabled ? 1 : 0.5)
        .animation(Theme.Motion.easeOut, value: focused)
        .animation(Theme.Motion.easeOut, value: invalid)
    }

    // MARK: - Field

    @ViewBuilder
    private var field: some View {
        Group {
            if multiline {
                TextField(placeholder, text: boundText, axis: .vertical)
                    .lineLimit(nil)
                    .padding(.vertical, 14)
                    .padding(.horizontal, Theme.Space.x5)
            } else {
                TextField(placeholder, text: boundText)
                    .padding(.leading, leadingInset)
                    // Reserve room on the right for the counter when present.
                    .padding(.trailing, maxLength != nil ? 56 : 18)
                    .frame(height: Theme.controlMd)
            }
        }
        .font(Theme.body)
        .foregroundStyle(Theme.text)
        .tint(Theme.primary)
        .focused($focused)
        .textFieldStyle(.plain)
    }

    /// Enforces `maxLength` by trimming on the way in, mirroring the web
    /// `maxLength` attribute.
    private var boundText: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                if let maxLength, newValue.count > maxLength {
                    text = String(newValue.prefix(maxLength))
                } else {
                    text = newValue
                }
            }
        )
    }

    // MARK: - Counter

    private var counterAlignment: Alignment {
        multiline ? .bottomTrailing : .trailing
    }

    @ViewBuilder
    private var counter: some View {
        if let maxLength {
            Text("\(count)/\(maxLength)")
                .font(BrandFont.mono(10, .bold))
                .foregroundStyle(counterColor(maxLength))
                .padding(.trailing, 14)
                .padding(.bottom, multiline ? 12 : 0)
                .allowsHitTesting(false)
                .animation(Theme.Motion.easeOut, value: count > Int(Double(maxLength) * 0.9))
        }
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var name = ""
        @State private var search = "grapevine"
        @State private var reply = "Funny story, the first time we met I genuinely thought you were someone else entirely."
        @State private var bad = "nope"

        var body: some View {
            ScrollView {
                VStack(spacing: Theme.Space.x6) {
                    GVInput("Your name", text: $name)

                    GVInput("Search", text: $search, leadingIcon: "magnifyingglass")

                    GVInput(
                        "Write your reply…",
                        text: $reply,
                        multiline: true,
                        maxLength: 280,
                        leadingIcon: nil
                    )

                    GVInput("That username is taken", text: $bad, invalid: true)

                    GVInput("Disabled", text: .constant(""))
                        .disabled(true)
                }
                .padding(Theme.gutter)
            }
            .background(Theme.bg)
        }
    }
    return PreviewHost()
}
