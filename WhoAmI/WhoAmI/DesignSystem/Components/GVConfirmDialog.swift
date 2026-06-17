import SwiftUI

/// Branded confirmation dialog — the design-system replacement for the stock iOS
/// `.confirmationDialog`/`.alert`. Present by binding an optional `GVConfirm`
/// (nil = hidden): `.gvConfirm($pending)`. Tapping the scrim or Cancel dismisses.
struct GVConfirm: Identifiable {
    let id = UUID()
    var title: String
    var message: String
    var confirmTitle: String
    var destructive: Bool
    var action: () -> Void

    init(title: String, message: String, confirmTitle: String,
         destructive: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.destructive = destructive
        self.action = action
    }
}

extension View {
    /// Overlay a branded confirmation when `item` is non-nil.
    func gvConfirm(_ item: Binding<GVConfirm?>) -> some View {
        modifier(GVConfirmModifier(item: item))
    }
}

private struct GVConfirmModifier: ViewModifier {
    @Binding var item: GVConfirm?

    func body(content: Content) -> some View {
        content.overlay {
            if let confirm = item {
                GVConfirmDialogView(confirm: confirm) { item = nil }
            }
        }
        .animation(Theme.Motion.spring, value: item?.id)
    }
}

private struct GVConfirmDialogView: View {
    let confirm: GVConfirm
    let dismiss: () -> Void
    @State private var shown = false

    var body: some View {
        ZStack {
            Theme.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }   // tap outside = cancel

            GVCard(padding: Theme.Space.x6) {
                VStack(spacing: Theme.Space.x4) {
                    Text(confirm.title)
                        .font(Theme.heading)
                        .foregroundStyle(Theme.text)
                        .multilineTextAlignment(.center)

                    Text(confirm.message)
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: Theme.Space.x3) {
                        GVButton(confirm.confirmTitle,
                                 variant: confirm.destructive ? .danger : .primary,
                                 full: true) {
                            dismiss()
                            confirm.action()
                        }
                        GVButton("Cancel", variant: .secondary, full: true) { dismiss() }
                    }
                    .padding(.top, Theme.Space.x2)
                }
            }
            .frame(maxWidth: 340)
            .padding(.horizontal, Theme.Space.x8)
            .scaleEffect(shown ? 1 : 0.92)
            .opacity(shown ? 1 : 0)
        }
        .onAppear { withAnimation(Theme.Motion.spring) { shown = true } }
    }
}
