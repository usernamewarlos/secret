import AuthenticationServices
import SwiftUI

struct EmailAuthView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: EmailAuthViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Sign in")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if vm == nil { vm = EmailAuthViewModel(auth: container.auth) }
        }
    }

    @ViewBuilder
    private func content(_ viewModel: EmailAuthViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: 16) {
            Picker("", selection: $vm.mode) {
                Text("Sign up").tag(EmailAuthViewModel.Mode.signUp)
                Text("Sign in").tag(EmailAuthViewModel.Mode.signIn)
            }
            .pickerStyle(.segmented)

            TextField("Email", text: $vm.email)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .textContentType(.emailAddress)

            SecureField("Password", text: $vm.password)
                .textFieldStyle(.roundedBorder)

            PrimaryButton(
                title: vm.busy ? "…" : (vm.mode == .signUp ? "Create account" : "Sign in"),
                enabled: !vm.busy
            ) {
                Task { await vm.submit() }
            }

            HStack {
                VStack { Divider() }
                Text("or").font(.footnote).foregroundStyle(.secondary)
                VStack { Divider() }
            }
            .padding(.vertical, 4)

            // Sign in with Apple.
            // TODO: Running this on-device/simulator requires the "Sign in with Apple"
            // capability (com.apple.developer.applesignin entitlement), which needs a paid
            // Apple Developer Team. The entitlement is intentionally NOT added to project.yml.
            SignInWithAppleButton(
                .signIn,
                onRequest: { request in
                    viewModel.configureAppleRequest(request)
                },
                onCompletion: { result in
                    Task { await viewModel.handleAppleCompletion(result) }
                }
            )
            .signInWithAppleButtonStyle(.black)
            .frame(height: 48)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .disabled(vm.busy)

            Button {
                Task { await viewModel.signInWithGoogle() }
            } label: {
                Text("Continue with Google")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.bordered)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
            .disabled(vm.busy)

            if let info = vm.info {
                Text(info).font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            if let error = vm.error {
                Text(error).font(.footnote).foregroundStyle(.red).multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding()
    }
}
