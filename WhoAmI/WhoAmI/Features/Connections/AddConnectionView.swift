import SwiftUI

struct AddConnectionView: View {
    @Bindable var vm: ConnectionsViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Grabber
            Capsule()
                .fill(Theme.borderStrong)
                .frame(width: 40, height: 5)
                .padding(.top, Theme.Space.x3)
                .padding(.bottom, Theme.Space.x5)

            // Header
            HStack(alignment: .center) {
                Text("Add someone")
                    .font(Theme.title)
                    .foregroundStyle(Theme.text)
                Spacer()
                GVIconButton(
                    icon: "xmark",
                    variant: .ghost,
                    size: .md,
                    accessibilityLabel: "Close"
                ) { dismiss() }
            }
            .padding(.bottom, Theme.Space.x4)

            // Search
            GVInput(
                "Search by name or @handle",
                text: $vm.searchText,
                leadingIcon: "magnifyingglass"
            )
            .onChange(of: vm.searchText) { _, _ in
                Task { await vm.search() }
            }
            .onSubmit { Task { await vm.search() } }

            // Results
            ScrollView {
                VStack(spacing: Theme.Space.x2) {
                    if vm.searchResults.isEmpty {
                        emptyState
                    } else {
                        ForEach(vm.searchResults) { user in
                            resultRow(user)
                        }
                    }

                    if let error = vm.error {
                        Text(error)
                            .font(Theme.label)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, Theme.Space.x2)
                    }
                }
                .padding(.top, Theme.Space.x4)
            }
            .scrollIndicators(.hidden)

            // Info card
            infoCard
                .padding(.top, Theme.Space.x4)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.bottom, Theme.Space.x9)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.bgElevated)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(Theme.bgElevated)
    }

    // MARK: - Result row

    @ViewBuilder
    private func resultRow(_ user: UserProfile) -> some View {
        HStack(spacing: Theme.Space.x3) {
            GVAvatar(
                name: user.displayName,
                imageURL: user.photoURL.flatMap(URL.init(string:)),
                size: .md
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName ?? "Someone")
                    .font(BrandFont.hanken(15, .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)

                if let handle = user.igHandle, !handle.isEmpty {
                    Text("@\(handle)")
                        .font(BrandFont.mono(11.5, .regular))
                        .foregroundStyle(Theme.textFaint)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            GVButton("Add", size: .sm, icon: "plus") {
                Task { await vm.add(user, role: .viewer) }
            }
        }
        .padding(.vertical, Theme.Space.x2)
        .padding(.horizontal, Theme.Space.x2)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: Theme.Space.x3) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.textFaint)
            Text("Search for people by name or @handle, then add them to your circle.")
                .font(Theme.body)
                .foregroundStyle(Theme.textMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Space.x10)
        .padding(.horizontal, Theme.Space.x4)
    }

    // MARK: - Info card

    private var infoCard: some View {
        GVCard(elevation: .flat, padding: Theme.Space.x4) {
            HStack(alignment: .top, spacing: Theme.Space.x3) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, 1)

                (
                    Text("New people join as ")
                        .foregroundStyle(Theme.textMuted)
                    + Text("viewers")
                        .foregroundStyle(Theme.text)
                        .fontWeight(.bold)
                    + Text(". Promoting to replier is a deliberate choice — you decide who gets to write about you.")
                        .foregroundStyle(Theme.textMuted)
                )
                .font(BrandFont.hanken(12.5, .regular))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
