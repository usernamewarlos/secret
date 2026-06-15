import SwiftUI

struct ProfileSetupView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: ProfileSetupViewModel?

    var body: some View {
        Group {
            if let vm {
                form(vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if vm == nil {
                vm = ProfileSetupViewModel(profile: container.profile, auth: container.auth)
            }
        }
    }

    @ViewBuilder
    private func form(_ viewModel: ProfileSetupViewModel) -> some View {
        @Bindable var vm = viewModel
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Display name", text: $vm.displayName)
                        .textContentType(.name)
                    TextField("Bio (optional)", text: $vm.bio, axis: .vertical)
                    TextField("Instagram handle (optional)", text: $vm.igHandle)
                        .textInputAutocapitalization(.never)
                }
                Section {
                    Text("Your profile fills in once your friends start answering prompts about you.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let error = vm.error {
                    Text(error).foregroundStyle(.red)
                }
                PrimaryButton(title: vm.busy ? "Saving…" : "Save profile", enabled: !vm.busy) {
                    Task {
                        if await vm.save() {
                            await container.session.refresh()
                        }
                    }
                }
            }
            .navigationTitle("Your profile")
        }
    }
}
