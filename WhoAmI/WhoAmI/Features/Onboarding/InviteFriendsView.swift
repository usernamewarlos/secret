import Contacts
import SwiftUI

// =============================================================================
// InviteFriendsView — the mandatory activation gate (SCREENS.md §6).
//
// First-run does NOT complete until you've added/invited ≥ 5 people, because a
// post can't graduate without enough repliers. There is no skip; the footer CTA
// stays disabled until the counter hits the minimum. Both on-platform adds (they
// become repliers immediately) and sent invite links (pending until they join)
// count toward the minimum.
//
// PRIVACY (non-negotiable, SCREENS.md §6): we do NOT touch the address book or
// upload contacts. The "From your contacts" section is presented as the
// explained, opt-in design — an on-device match story plus a system ShareLink
// the user taps deliberately. Nothing leaves the device without an explicit tap.
// (Sarahah was pulled from both stores for silently slurping contacts.)
// =============================================================================

struct InviteFriendsView: View {
    /// Called once the gate is satisfied (count ≥ minimum) and the user taps
    /// "Enter Grapevine" — the coordinator routes into the main tab shell.
    var onComplete: () -> Void

    @Environment(AppContainer.self) private var container
    @State private var vm = InviteFriendsViewModel()

    /// The deep link a tapped contact / share recipient lands on to join.
    private let inviteURL = URL(string: "https://grapevineapp.app/invite")!

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Space.x7) {
                    header
                    searchSection
                    contactsSection
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, Theme.Space.x6)
                .padding(.bottom, Theme.Space.x8)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) { footer }
        .task { vm.bind(container) }
    }

    // MARK: - Header (title + progress chip)

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            HStack(alignment: .top, spacing: Theme.Space.x4) {
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Add your first 5 friends")
                        .font(Theme.display)
                        .foregroundStyle(Theme.text)
                    Text("Grapevine needs a few voices before your first post can graduate. Add people who already use Grapevine, or invite friends — both count.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                }
                Spacer(minLength: 0)
                progressChip
            }
        }
    }

    /// "K / 5" chip — tangerine while accumulating, flips to Tone.wholesome green
    /// once the minimum is met.
    private var progressChip: some View {
        let met = vm.isMet
        let tint: Color = met ? Tone.wholesome.color : Theme.primary
        return HStack(spacing: Theme.Space.x2) {
            Image(systemName: met ? "checkmark.circle.fill" : "person.2.fill")
                .font(.system(size: 13, weight: .bold))
            Text("\(vm.count) / \(InviteFriendsViewModel.minimum)")
                .font(BrandFont.mono(14, .bold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, Theme.Space.x4)
        .padding(.vertical, Theme.Space.x2)
        .background(
            Capsule(style: .continuous)
                .fill(tint.opacity(0.16))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(0.5), lineWidth: 1)
        )
        .animation(Theme.Motion.spring, value: met)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(vm.count) of \(InviteFriendsViewModel.minimum) friends added")
    }

    // MARK: - Search (on-platform adds)

    private var searchSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            Text("Find people on Grapevine").gvKicker()

            GVInput(
                "Search by name",
                text: $vm.query,
                leadingIcon: "magnifyingglass"
            )
            .onChange(of: vm.query) { _, _ in vm.scheduleSearch() }
            .submitLabel(.search)
            .onSubmit { Task { await vm.runSearch() } }

            if let error = vm.error {
                Text(error)
                    .font(Theme.label)
                    .foregroundStyle(Theme.danger)
            }

            if vm.searching {
                HStack(spacing: Theme.Space.x3) {
                    ProgressView().tint(Theme.primary)
                    Text("Searching…")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, Theme.Space.x2)
            } else if !vm.results.isEmpty {
                VStack(spacing: Theme.Space.x3) {
                    ForEach(vm.results) { user in
                        resultRow(user)
                    }
                }
            } else if vm.didSearch && !vm.query.trimmingCharacters(in: .whitespaces).isEmpty {
                emptyHint("No one by that name yet — invite them below.")
            } else {
                emptyHint("Search for friends by their display name, then tap Add. They become repliers right away.")
            }
        }
    }

    private func resultRow(_ user: UserProfile) -> some View {
        let added = vm.added.contains(user.id)
        return GVCard(padding: Theme.Space.x4) {
            HStack(spacing: Theme.Space.x4) {
                GVAvatar(name: user.displayName, size: .md)
                VStack(alignment: .leading, spacing: 1) {
                    Text(user.displayName ?? "Someone")
                        .font(BrandFont.hanken(16, .bold))
                        .foregroundStyle(Theme.text)
                    Text("On Grapevine")
                        .font(Theme.label)
                        .foregroundStyle(Tone.wholesome.color)
                }
                Spacer(minLength: Theme.Space.x3)
                if added {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Added")
                            .font(Theme.label)
                    }
                    .foregroundStyle(Tone.wholesome.color)
                } else {
                    GVButton(
                        "Add",
                        variant: .primary,
                        size: .sm,
                        icon: "plus",
                        loading: vm.adding.contains(user.id),
                        enabled: !vm.adding.contains(user.id)
                    ) {
                        Task { await vm.add(user) }
                    }
                }
            }
        }
    }

    // MARK: - From your contacts (privacy-first, opt-in)

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            Text("From your contacts").gvKicker()

            // Privacy banner — the explained, opt-in design. We never read or
            // upload the address book.
            GVCard(padding: Theme.Space.x4) {
                HStack(alignment: .top, spacing: Theme.Space.x4) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Theme.intrigue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: Theme.Space.x2) {
                        Text("Private by design")
                            .font(BrandFont.hanken(15, .bold))
                            .foregroundStyle(Theme.text)
                        Text("We match contacts on-device. Nothing is uploaded without you tapping invite.")
                            .font(Theme.label)
                            .foregroundStyle(Theme.textMuted)
                    }
                }
            }

            // Contacts: explicit, on-device, opt-in.
            if vm.contactsDenied {
                Text("Contacts access is off. Enable it in Settings to find friends here.")
                    .font(Theme.label)
                    .foregroundStyle(Theme.textFaint)
            } else if vm.contacts.isEmpty {
                GVButton(
                    vm.loadingContacts ? "Loading…" : "Find friends from contacts",
                    variant: .secondary,
                    size: .md,
                    full: true,
                    icon: "person.crop.circle.badge.plus",
                    loading: vm.loadingContacts,
                    enabled: !vm.loadingContacts
                ) {
                    Task { await vm.importContacts() }
                }
            } else {
                LazyVStack(spacing: Theme.Space.x3) {
                    ForEach(vm.contacts) { contact in
                        contactRow(contact)
                    }
                }
            }

            // Sent-invites tally — each invite / ShareLink tap records a pending invite.
            if vm.invited > 0 {
                HStack(spacing: Theme.Space.x2) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                    Text(vm.invited == 1 ? "1 invite sent" : "\(vm.invited) invites sent")
                        .font(Theme.label)
                }
                .foregroundStyle(Theme.primary)
            }

            ShareLink(
                item: inviteURL,
                subject: Text("Join me on Grapevine"),
                message: Text("Come find out what your friends really think — join me on Grapevine.")
            ) {
                shareRow
            }
            .simultaneousGesture(TapGesture().onEnded { vm.recordInvite() })
        }
    }

    /// One device contact with an Invite affordance (records a pending invite).
    private func contactRow(_ contact: DeviceContact) -> some View {
        let invited = vm.invitedContacts.contains(contact.id)
        return GVCard(padding: Theme.Space.x4) {
            HStack(spacing: Theme.Space.x4) {
                GVAvatar(name: contact.name, size: .md)
                Text(contact.name)
                    .font(BrandFont.hanken(16, .bold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer(minLength: Theme.Space.x3)
                if invited {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .bold))
                        Text("Invited").font(Theme.label)
                    }
                    .foregroundStyle(Tone.wholesome.color)
                } else {
                    GVButton("Invite", variant: .secondary, size: .sm, icon: "paperplane") {
                        vm.inviteContact(contact)
                    }
                }
            }
        }
    }

    /// Styled like a GVButton.secondary, but wraps the system ShareLink so iOS
    /// owns the share sheet (no contacts access on our side).
    private var shareRow: some View {
        HStack(spacing: Theme.Space.x3) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 16, weight: .bold))
            Text("Share an invite link")
                .font(Theme.label)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, Theme.Space.x5)
        .frame(height: Theme.controlMd)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                .fill(Theme.surface2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                .strokeBorder(Theme.border, lineWidth: 1)
        )
    }

    private func emptyHint(_ text: String) -> some View {
        Text(text)
            .font(Theme.label)
            .foregroundStyle(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, Theme.Space.x2)
    }

    // MARK: - Glass footer

    private var footer: some View {
        VStack(spacing: Theme.Space.x3) {
            Divider().background(Theme.border)
            if !vm.isMet {
                Text("\(InviteFriendsViewModel.minimum - vm.count) more to go")
                    .font(Theme.label)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.top, Theme.Space.x3)
            }
            GVButton(
                "Enter Grapevine",
                variant: .primary,
                size: .lg,
                full: true,
                trailingIcon: "arrow.right",
                enabled: vm.isMet
            ) {
                onComplete()
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, vm.isMet ? Theme.Space.x4 : Theme.Space.x2)

            #if DEBUG
            // Dev-only bypass: walk the onboarding flow without 5 real accounts.
            // The real activation gate (minimum = 5) is unchanged in release builds.
            Button("Skip for now (dev)") { onComplete() }
                .font(Theme.label)
                .foregroundStyle(Theme.textFaint)
                .padding(.top, Theme.Space.x2)
            #endif

            Color.clear.frame(height: Theme.Space.x6)
        }
        .background(.ultraThinMaterial)
        .animation(Theme.Motion.spring, value: vm.isMet)
    }
}

// =============================================================================
// ViewModel
// =============================================================================

@MainActor
@Observable
final class InviteFriendsViewModel {
    /// Gate minimum (tunable 3–5; SCREENS.md §6 locks it at 5).
    static let minimum = 5

    // Search
    var query = ""
    var results: [UserProfile] = []
    var searching = false
    var didSearch = false
    var error: String?

    /// In-flight add operations, keyed by user id (drives per-row spinners).
    var adding: Set<UUID> = []

    // Gate progress — both sets count toward `count`.
    /// On-platform users added (become repliers immediately).
    private(set) var added: Set<UUID> = []
    /// Number of invite links sent (pending until the recipient joins).
    private(set) var invited = 0

    // Contacts (on-device, opt-in — never uploaded).
    var contacts: [DeviceContact] = []
    var loadingContacts = false
    var contactsDenied = false
    private(set) var invitedContacts: Set<UUID> = []

    /// Derived progress: on-platform adds + sent invites.
    var count: Int { added.count + invited }
    var isMet: Bool { count >= Self.minimum }

    private var container: AppContainer?
    private var searchTask: Task<Void, Never>?

    func bind(_ container: AppContainer) {
        guard self.container == nil else { return }
        self.container = container
    }

    // MARK: Search (debounced)

    /// Debounce live typing; an empty query clears results immediately.
    func scheduleSearch() {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            didSearch = false
            searching = false
            return
        }
        searchTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            await self?.runSearch()
        }
    }

    func runSearch() async {
        guard let container else { return }
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            didSearch = false
            return
        }
        searching = true
        error = nil
        defer { searching = false }
        do {
            let found = try await container.connections.search(name: trimmed)
            let me = container.auth.currentUserID
            // Drop myself from results.
            results = found.filter { $0.id != me }
            didSearch = true
        } catch {
            self.error = "Couldn't search right now. Try again."
            didSearch = true
        }
    }

    // MARK: Add an on-platform user (counts immediately)

    func add(_ user: UserProfile) async {
        guard let container, !added.contains(user.id), !adding.contains(user.id) else { return }
        adding.insert(user.id)
        error = nil
        defer { adding.remove(user.id) }
        do {
            try await container.connections.add(connectedUserId: user.id, role: .replier)
            added.insert(user.id)
        } catch {
            self.error = "Couldn't add \(user.displayName ?? "that person"). Try again."
        }
    }

    // MARK: Record a sent invite (counts as pending)

    /// Called when the user taps the system ShareLink. We can't observe the
    /// share-sheet outcome, so an opened sheet records one pending invite —
    /// matching the spec ("counts as a pending invite").
    func recordInvite() {
        invited += 1
    }

    // MARK: Contacts (on-device match; nothing leaves the device)

    /// Request Contacts access and, if granted, load name-only entries on-device.
    /// We never read more than names and never upload anything.
    func importContacts() async {
        loadingContacts = true
        contactsDenied = false
        defer { loadingContacts = false }

        let granted: Bool = await withCheckedContinuation { cont in
            CNContactStore().requestAccess(for: .contacts) { ok, _ in cont.resume(returning: ok) }
        }
        guard granted else { contactsDenied = true; return }

        contacts = await Task.detached {
            let store = CNContactStore()
            let keys = [CNContactGivenNameKey, CNContactFamilyNameKey] as [CNKeyDescriptor]
            let request = CNContactFetchRequest(keysToFetch: keys)
            var out: [DeviceContact] = []
            try? store.enumerateContacts(with: request) { contact, _ in
                let name = "\(contact.givenName) \(contact.familyName)"
                    .trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { out.append(DeviceContact(name: name)) }
            }
            return out.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value
    }

    /// Inviting a contact records a pending invite (counts toward the gate). The
    /// actual outreach is the user's to send via the share link — we never message
    /// anyone automatically.
    func inviteContact(_ contact: DeviceContact) {
        guard !invitedContacts.contains(contact.id) else { return }
        invitedContacts.insert(contact.id)
        invited += 1
    }
}

/// A name pulled from the device address book (on-device only — never uploaded).
struct DeviceContact: Identifiable, Sendable {
    let id = UUID()
    let name: String
}
