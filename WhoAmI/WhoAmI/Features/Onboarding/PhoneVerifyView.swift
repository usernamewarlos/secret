import SwiftUI

/// Phone SMS OTP verification (PRODUCT.md §6.1). Used as a (skippable) onboarding
/// step and from Settings → Verification. On success it flips users.verified_phone.
///
/// NOTE: delivering real codes requires an SMS provider configured in Supabase
/// Auth (Twilio/MessageBird/etc.). Until one is set up, `sendOTP` returns an
/// error, surfaced in the UI — the flow is wired and ready.
struct PhoneVerifyView: View {
    var onComplete: () -> Void
    var allowSkip: Bool = false

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: PhoneVerifyViewModel?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let vm {
                content(vm)
            } else {
                ProgressView().tint(Theme.primary)
            }
        }
        .onAppear { if vm == nil { vm = PhoneVerifyViewModel(auth: container.auth) } }
    }

    @ViewBuilder
    private func content(_ viewModel: PhoneVerifyViewModel) -> some View {
        @Bindable var vm = viewModel
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                RoundedRectangle(cornerRadius: Theme.Radius.xl, style: .continuous)
                    .fill(Theme.intrigueSoft)
                    .frame(width: 96, height: 96)
                    .overlay {
                        Image(systemName: "iphone.gen3")
                            .font(.system(size: 42, weight: .semibold))
                            .foregroundStyle(Theme.intrigue)
                    }
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text(vm.step == .enterPhone ? "Verify your number" : "Enter the code")
                        .font(Theme.display)
                        .foregroundStyle(Theme.text)
                    Text(vm.step == .enterPhone
                         ? "Your number keeps Grapevine real-people-only. We only use it to verify you."
                         : "We sent a 6-digit code to \(vm.phone).")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if vm.step == .enterPhone {
                    GVInput("+1 555 123 4567", text: $vm.phone, leadingIcon: "phone")
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    GVButton(vm.busy ? "Sending…" : "Send code", variant: .intrigue, full: true,
                             loading: vm.busy, enabled: !vm.busy) {
                        Task { await vm.sendCode() }
                    }
                } else {
                    GVInput("123456", text: $vm.code, leadingIcon: "number")
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                    GVButton(vm.busy ? "Verifying…" : "Verify", variant: .intrigue, full: true,
                             loading: vm.busy, enabled: !vm.busy) {
                        Task {
                            if await vm.verify() {
                                try? await container.profile.setPhoneVerified()
                                onComplete()
                                dismiss()
                            }
                        }
                    }
                }

                if let error = vm.error {
                    Text(error)
                        .font(Theme.label)
                        .foregroundStyle(Theme.danger)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if allowSkip {
                    Button("Skip for now") { onComplete() }
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.x2)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x8)
            .padding(.bottom, Theme.Space.x8)
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }
}
