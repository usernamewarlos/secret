import SwiftUI

struct PhoneVerifyView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: PhoneVerifyViewModel?

    var body: some View {
        Group {
            if let vm {
                content(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if vm == nil { vm = PhoneVerifyViewModel(auth: container.auth) }
        }
        .navigationTitle("Verify")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func content(_ viewModel: PhoneVerifyViewModel) -> some View {
        @Bindable var vm = viewModel
        VStack(spacing: 20) {
            switch vm.step {
            case .enterPhone:
                Text("Verify your number")
                    .font(.title2.bold())
                TextField("+1 555 123 4567", text: $vm.phone)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.phonePad)
                    .textContentType(.telephoneNumber)
                PrimaryButton(title: vm.busy ? "Sending…" : "Send code", enabled: !vm.busy) {
                    Task { await vm.sendCode() }
                }
            case .enterCode:
                Text("Enter the code")
                    .font(.title2.bold())
                Text("Sent to \(vm.phone)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("123456", text: $vm.code)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                PrimaryButton(title: vm.busy ? "Verifying…" : "Verify", enabled: !vm.busy) {
                    Task { await vm.verify() }
                }
            }

            if let error = vm.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}
