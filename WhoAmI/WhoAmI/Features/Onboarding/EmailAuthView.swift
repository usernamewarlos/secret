import AuthenticationServices
import SwiftUI

/// End-of-onboarding sign in. Wordmark, "Let's get you in" heading, Continue with
/// Apple / Continue with Google as the primary paths, an OR EMAIL divider, and an
/// email + Continue fallback. All auth actions and VM bindings are preserved from
/// the original screen — only the chrome is restyled to the Grapevine design system.
struct EmailAuthView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: EmailAuthViewModel?

    /// When set (dev onboarding replay only), shows a "Skip sign-in" affordance so
    /// the replay can advance past this page without a real re-auth. nil in normal
    /// use — the real flow advances when auth state flips.
    var onReplayContinue: (() -> Void)? = nil

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
                    .tint(Theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            if vm == nil { vm = EmailAuthViewModel(auth: container.auth) }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: EmailAuthViewModel) -> some View {
        @Bindable var vm = viewModel

        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // Wordmark
                Wordmark(size: 22, withMark: true)
                    .padding(.bottom, Theme.Space.x9)

                // Heading + subhead
                Text("Let's get you in")
                    .font(BrandFont.hanken(34, .heavy))
                    .tracking(-1)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Theme.Space.x2)

                Text("Your friends are already talking. Probably.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Theme.Space.x7)

                // Social sign-in
                VStack(spacing: Theme.Space.x3) {
                    appleButton(viewModel, busy: vm.busy)

                    googleButton(viewModel, busy: vm.busy)
                }

                // OR EMAIL divider
                divider
                    .padding(.vertical, Theme.Space.x6)

                // Email fallback
                VStack(spacing: Theme.Space.x3) {
                    GVInput(
                        "you@email.com",
                        text: $vm.email,
                        leadingIcon: "envelope"
                    )
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textContentType(.emailAddress)

                    // Password is required by the email/password VM; surface it as a
                    // second field so the existing submit() path stays intact.
                    GVInput(
                        "Password",
                        text: $vm.password,
                        leadingIcon: "lock"
                    )
                    .textContentType(.password)

                    GVButton(
                        "Continue",
                        size: .lg,
                        full: true,
                        trailingIcon: "arrow.right",
                        loading: vm.busy,
                        enabled: !vm.busy
                    ) {
                        Task { await viewModel.submit() }
                    }

                    if let cont = onReplayContinue {
                        Button("Skip sign-in (dev)") { cont() }
                            .font(Theme.label)
                            .foregroundStyle(Theme.textFaint)
                            .frame(maxWidth: .infinity)
                            .padding(.top, Theme.Space.x2)
                    }
                }

                // Status messages
                if let info = vm.info {
                    Text(info)
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.x4)
                }
                if let error = vm.error {
                    Text(error)
                        .font(Theme.label)
                        .foregroundStyle(Theme.danger)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.x4)
                }

                Spacer(minLength: Theme.Space.x6)

                // Terms line
                Text("By continuing you agree to our Terms & confirm you're 18+. We use plain, modest moderation — read how it works.")
                    .font(BrandFont.hanken(12, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Theme.Space.x7)
            .padding(.top, Theme.Space.x8)
            .padding(.bottom, Theme.Space.x7)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Apple

    /// Continue with Apple — the real, visible native button (capsule-clipped to
    /// match the design). Tapping it runs the unchanged configureAppleRequest /
    /// handleAppleCompletion flow on the view model.
    ///
    /// NOTE: project.yml `DEVELOPMENT_TEAM` is set (N89556Y88J) — run `xcodegen
    /// generate` so it lands in the project. A real Apple sign-in still needs the
    /// device/simulator signed into an Apple ID; otherwise the sheet can't complete
    /// (surfaced via vm.error).
    @ViewBuilder
    private func appleButton(_ viewModel: EmailAuthViewModel, busy: Bool) -> some View {
        SignInWithAppleButton(
            .continue,
            onRequest: { request in
                viewModel.configureAppleRequest(request)
            },
            onCompletion: { result in
                Task { await viewModel.handleAppleCompletion(result) }
            }
        )
        .signInWithAppleButtonStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: Theme.controlLg)
        .clipShape(Capsule())
        .opacity(busy ? 0.6 : 1)
        .disabled(busy)
        .accessibilityLabel("Continue with Apple")
    }

    // MARK: - Google

    /// Continue with Google — `Theme.surface` fill with a strong border, wired to
    /// the unchanged `signInWithGoogle()` action.
    @ViewBuilder
    private func googleButton(_ viewModel: EmailAuthViewModel, busy: Bool) -> some View {
        Button {
            Task { await viewModel.signInWithGoogle() }
        } label: {
            HStack(spacing: Theme.Space.x2) {
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .semibold))
                Text("Continue with Google")
                    .font(BrandFont.hanken(16, .bold))
            }
            .foregroundStyle(Theme.text)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.controlLg)
            .background(Theme.surface, in: Capsule())
            .overlay(
                Capsule().strokeBorder(Theme.borderStrong, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .opacity(busy ? 0.6 : 1)
        .disabled(busy)
        .accessibilityLabel("Continue with Google")
    }

    // MARK: - Divider

    private var divider: some View {
        HStack(spacing: Theme.Space.x4) {
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
            Text("OR EMAIL")
                .font(BrandFont.mono(10.5, .bold))
                .tracking(1.6)
                .foregroundStyle(Theme.textFaint)
            Rectangle()
                .fill(Theme.divider)
                .frame(height: 1)
        }
    }
}
