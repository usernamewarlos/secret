import SwiftUI

struct AnswerView: View {
    let prompt: Prompt
    let owner: UserProfile
    var onSubmitted: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AnswerViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    form(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(owner.displayName ?? "Answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if vm == nil {
                    vm = AnswerViewModel(replies: container.replies, prompt: prompt, owner: owner)
                }
            }
        }
    }

    @ViewBuilder
    private func form(_ viewModel: AnswerViewModel) -> some View {
        @Bindable var vm = viewModel
        Form {
            Section {
                Text(prompt.text).font(.headline)
            }
            Section("Your answer") {
                TextField("Say something true and funny…", text: $vm.body, axis: .vertical)
                    .lineLimit(3...8)
                Toggle("Private — only you can read it", isOn: $vm.isPrivate)
            }
            Section {
                Text(vm.isPrivate
                     ? "Others will see that you left a private reply, but only you can read it — and only you can ever reveal it."
                     : "Your name shows on this reply once the post graduates.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let error = vm.error {
                Text(error).foregroundStyle(.red)
            }
            PrimaryButton(title: vm.busy ? "Sending…" : "Submit", enabled: !vm.busy) {
                Task {
                    if await vm.submit() {
                        onSubmitted()
                        dismiss()
                    }
                }
            }
        }
    }
}
