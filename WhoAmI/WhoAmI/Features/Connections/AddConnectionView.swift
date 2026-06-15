import SwiftUI

struct AddConnectionView: View {
    @Bindable var vm: ConnectionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("Search by name", text: $vm.searchText)
                            .textInputAutocapitalization(.never)
                            .onSubmit { Task { await vm.search() } }
                        Button("Search") { Task { await vm.search() } }
                    }
                }
                Section {
                    if vm.searchResults.isEmpty {
                        Text("Search for people by their display name, then add them as a viewer (can see your profile) or replier (can write about you).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(vm.searchResults) { user in
                        HStack {
                            Text(user.displayName ?? "Someone")
                            Spacer()
                            Menu("Add") {
                                Button("As viewer") { Task { await vm.add(user, role: .viewer) } }
                                Button("As replier") { Task { await vm.add(user, role: .replier) } }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
