import SwiftUI

/// Placeholder main surface. The daily prompt + answer loop lands in Phase 2;
/// the gist + archive in Phases 3–4 (see docs/PRODUCT.md §13).
struct HomeView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer()
                Text("Who Am I")
                    .font(.largeTitle.bold())
                Text("You're in. The daily prompt loop arrives in Phase 2.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Sign out") {
                    Task { await container.session.signOut() }
                }
                .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Today")
        }
    }
}
