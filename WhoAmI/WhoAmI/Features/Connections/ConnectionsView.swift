import SwiftUI

struct ConnectionsView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: ConnectionsViewModel?
    @State private var showingAdd = false
    @State private var pendingConfirm: GVConfirm?
    @State private var toast: String?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.bg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if vm == nil {
                    let model = ConnectionsViewModel(
                        connections: container.connections,
                        profile: container.profile,
                        myId: container.auth.currentUserID
                    )
                    vm = model
                    Task { await model.load() }
                }
            }
            .sheet(isPresented: $showingAdd) {
                if let vm { AddConnectionView(vm: vm) }
            }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: ConnectionsViewModel) -> some View {
        let replierCount = vm.rows.filter { $0.connection.role == .replier }.count
        let viewerCount = vm.rows.filter { $0.connection.role == .viewer }.count

        List {
            // Header + subtitle + summary cards live in a single chrome-free section.
            Section {
                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    header

                    Text("Reach vs trust — tap a role chip to flip anyone between viewer and replier. Counts update live.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)

                    HStack(spacing: Theme.Space.x3) {
                        SummaryCard(
                            icon: "pencil.line",
                            label: "Repliers",
                            count: replierCount,
                            caption: "can write about you",
                            tint: Theme.primary,
                            background: Theme.primarySoft,
                            border: Theme.primary.opacity(0.24)
                        )
                        SummaryCard(
                            icon: "eye.fill",
                            label: "Viewers",
                            count: viewerCount,
                            caption: "reach, can't write",
                            tint: Theme.textMuted,
                            background: Theme.surface2,
                            border: Theme.border
                        )
                    }
                }
                .listRowInsets(EdgeInsets(top: Theme.Space.x4, leading: Theme.gutter, bottom: Theme.Space.x4, trailing: Theme.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Empty state.
            if vm.rows.isEmpty && !vm.loading {
                Text("Add people to build your circle. Make someone a replier and they can answer prompts about you.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .listRowInsets(EdgeInsets(top: Theme.Space.x2, leading: Theme.gutter, bottom: Theme.Space.x2, trailing: Theme.gutter))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            // Connection rows.
            ForEach(vm.rows) { row in
                ConnectionRowView(
                    row: row,
                    onToggleRole: {
                        let next: ConnectionRole = row.connection.role == .replier ? .viewer : .replier
                        Task { await vm.setRole(connectionId: row.connection.id, role: next) }
                    },
                    onRevoke: {
                        pendingConfirm = GVConfirm(
                            title: "Revoke this person?",
                            message: "This removes their replies everywhere and re-spins affected gists. It can't be undone.",
                            confirmTitle: "Revoke",
                            destructive: true
                        ) { Task { await vm.revoke(row.connection.connectedUserId) } }
                    },
                    onBlock: {
                        pendingConfirm = GVConfirm(
                            title: "Block this person?",
                            message: "They won't be able to see you, add you, or reply — in either direction. Stronger than revoke.",
                            confirmTitle: "Block",
                            destructive: true
                        ) {
                            Task {
                                await vm.block(row.connection.connectedUserId)
                                toast = "Blocked — they can't see or add you."
                            }
                        }
                    }
                )
                .listRowInsets(EdgeInsets(top: Theme.Space.x1, leading: Theme.gutter, bottom: Theme.Space.x1, trailing: Theme.gutter))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Footer hint.
            if !vm.rows.isEmpty {
                Text("Swipe a row to revoke or block. Revoking removes their replies everywhere and re-spins affected gists.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.textFaint)
                    .listRowInsets(EdgeInsets(top: Theme.Space.x4, leading: Theme.gutter, bottom: Theme.Space.x6, trailing: Theme.gutter))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if let error = vm.error {
                Text(error)
                    .font(Theme.label)
                    .foregroundStyle(Theme.danger)
                    .listRowInsets(EdgeInsets(top: Theme.Space.x2, leading: Theme.gutter, bottom: Theme.Space.x2, trailing: Theme.gutter))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg.ignoresSafeArea())
        .refreshable { await vm.load() }
        .gvConfirm($pendingConfirm)
        .overlay(alignment: .bottom) {
            if let message = toast {
                Text(message)
                    .font(Theme.label)
                    .foregroundStyle(Theme.text)
                    .padding(.horizontal, Theme.Space.x5)
                    .padding(.vertical, Theme.Space.x3)
                    .background(Capsule().fill(Theme.surface2))
                    .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                    .padding(.bottom, Theme.Space.x6)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task { try? await Task.sleep(nanoseconds: 2_200_000_000); toast = nil }
            }
        }
        .animation(Theme.Motion.spring, value: toast)
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("People")
                .font(Theme.display)
                .foregroundStyle(Theme.text)
            Spacer()
            GVIconButton(
                icon: "person.badge.plus",
                variant: .primary,
                accessibilityLabel: "Add people"
            ) { showingAdd = true }
        }
    }
}

// MARK: - Summary card

private struct SummaryCard: View {
    let icon: String
    let label: String
    let count: Int
    let caption: String
    let tint: Color
    let background: Color
    let border: Color

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x1) {
            HStack(spacing: 7) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(tint)
                Text(label)
                    .gvKicker(tint)
            }
            .padding(.bottom, 2)

            Text("\(count)")
                .font(BrandFont.hanken(30, .heavy))
                .foregroundStyle(Theme.text)

            Text(caption)
                .font(Theme.label)
                .foregroundStyle(Theme.textMuted)
                .padding(.top, 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Space.x4)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .strokeBorder(border, lineWidth: 1)
        )
    }
}

// MARK: - Connection row

private struct ConnectionRowView: View {
    let row: ConnectionsViewModel.Row
    var onToggleRole: () -> Void
    var onRevoke: () -> Void
    var onBlock: () -> Void

    private var isReplier: Bool { row.connection.role == .replier }
    private var name: String { row.user?.displayName ?? "Someone" }
    private var handle: String? {
        guard let ig = row.user?.igHandle, !ig.isEmpty else { return nil }
        return "@\(ig)"
    }

    var body: some View {
        NavigationLink {
            ProfileView(ownerId: row.user?.id ?? row.connection.connectedUserId,
                        title: row.user?.displayName)
        } label: {
            HStack(spacing: Theme.Space.x3) {
                GVAvatar(name: name, imageURL: row.user?.photoURL.flatMap(URL.init(string:)), size: .md, ring: isReplier)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(BrandFont.hanken(15, .bold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    if let handle {
                        Text(handle)
                            .font(BrandFont.mono(11.5, .regular))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                RoleChip(isReplier: isReplier, action: onToggleRole)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing) {
            Button("Revoke", role: .destructive, action: onRevoke)
            Button(isReplier ? "Make viewer" : "Make replier", action: onToggleRole)
                .tint(Theme.primary)
        }
        .swipeActions(edge: .leading) {
            Button("Block", action: onBlock).tint(Theme.danger)
        }
    }
}

// MARK: - Role chip (toggles role live)

private struct RoleChip: View {
    let isReplier: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: isReplier ? "pencil" : "eye")
                    .font(.system(size: 13, weight: .semibold))
                Text(isReplier ? "Replier" : "Viewer")
                    .font(BrandFont.mono(10, .bold))
                    .tracking(1.0)
                    .textCase(.uppercase)
            }
            .foregroundStyle(isReplier ? Theme.primary : Theme.textMuted)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                Capsule(style: .continuous)
                    .fill(isReplier ? Theme.primarySoft : Theme.surface2)
            )
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(isReplier ? Theme.primary.opacity(0.30) : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isReplier ? "Replier, tap to make viewer" : "Viewer, tap to make replier")
    }
}
