import SwiftUI
import Supabase

// =============================================================================
// SettingsView — pushed from the gear in the "You" tab (ProfileView header).
//
// A grouped scroll of GVCard sections (SCREENS.md §5):
//   • Profile summary row → EditProfileView
//   • ACCOUNT            — Edit profile · Verification (PHONE PENDING)
//   • YOUR DEFAULTS      — Default spice level → DefaultSpiceView (ToneTag)
//   • NOTIFICATIONS & PRIVACY — Notifications → NotificationPreferencesView ·
//                          Blocked users · N → BlockedUsersView
//   • ABOUT              — How Grapevine works → AboutView
//   • Sign out (secondary, full) + Delete account (danger text + confirm)
//   • Footer: GRAPEVINE · V1.0.0 (24)
//
// All sub-screens live in this file. Everything compiles against the live
// services; missing data degrades gracefully (placeholder copy / empty state).
// =============================================================================

struct SettingsView: View {
    @Environment(AppContainer.self) private var container

    @State private var profile: UserProfile?
    @State private var blockedCount: Int = 0
    @State private var pendingConfirm: GVConfirm?
    @State private var loaded = false

    #if DEBUG
    @State private var devStatus: String?
    @State private var devBusy = false
    #endif

    private var displayName: String {
        if let n = profile?.displayName, !n.isEmpty { return n }
        return "You"
    }

    private var handleLine: String {
        if let h = profile?.igHandle, !h.isEmpty { return "@\(h)" }
        return "@you"
    }

    private var photoURL: URL? {
        guard let s = profile?.photoURL, let url = URL(string: s) else { return nil }
        return url
    }

    private var currentSpice: Tone {
        Tone(spice: profile?.defaultSpiceLevel ?? "social")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.x6) {
                profileSummary

                section("Account") {
                    NavigationLink {
                        EditProfileView(profile: profile)
                    } label: {
                        SettingsRow(icon: "person.text.rectangle", title: "Edit profile")
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        VerificationView(profile: profile)
                    } label: {
                        SettingsRow(
                            icon: "checkmark.seal",
                            title: "Verification",
                            trailing: { VerificationBadge(verified: profile?.verifiedPhone ?? false) }
                        )
                    }
                    .buttonStyle(.plain)
                }

                section("Your defaults") {
                    NavigationLink {
                        DefaultSpiceView(initial: currentSpice) { newProfile in
                            profile = newProfile
                        }
                    } label: {
                        SettingsRow(
                            icon: "dial.medium",
                            title: "Default spice level",
                            subtitle: "Your standing comfort ceiling",
                            trailing: { ToneTag(currentSpice, size: .sm) }
                        )
                    }
                    .buttonStyle(.plain)
                }

                section("Notifications & privacy") {
                    NavigationLink {
                        NotificationPreferencesView()
                    } label: {
                        SettingsRow(icon: "bell", title: "Notifications")
                    }
                    .buttonStyle(.plain)

                    rowDivider

                    NavigationLink {
                        BlockedUsersView()
                    } label: {
                        SettingsRow(
                            icon: "hand.raised",
                            title: "Blocked users",
                            trailing: {
                                Text("\(blockedCount)")
                                    .font(BrandFont.mono(13, .bold))
                                    .foregroundStyle(Theme.textFaint)
                            }
                        )
                    }
                    .buttonStyle(.plain)
                }

                section("About") {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsRow(icon: "info.circle", title: "How Grapevine works")
                    }
                    .buttonStyle(.plain)
                }

                #if DEBUG
                devTools
                #endif

                dangerZone

                footer
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x4)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .gvConfirm($pendingConfirm)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !loaded else { return }
            loaded = true
            await load()
        }
        .refreshable { await load() }
    }

    // MARK: - Profile summary

    private var profileSummary: some View {
        NavigationLink {
            EditProfileView(profile: profile)
        } label: {
            GVCard(interactive: true) {
                HStack(spacing: Theme.Space.x4) {
                    GVAvatar(name: displayName, imageURL: photoURL, size: .lg, ring: true)

                    VStack(alignment: .leading, spacing: Theme.Space.x1) {
                        Text(displayName)
                            .font(Theme.title)
                            .foregroundStyle(Theme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(handleLine)
                            .font(BrandFont.mono(12, .regular))
                            .foregroundStyle(Theme.textFaint)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.textFaint)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Dev tools (DEBUG only)

    #if DEBUG
    private var devTools: some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text("Dev tools").gvKicker()

            GVButton("Seed fake friends", variant: .secondary, size: .md, full: true,
                     icon: "person.3", loading: devBusy, enabled: !devBusy) {
                runDev { "Connected \(try await DevTools.seedFriends()) fake friends." }
            }
            GVButton("Generate responses + gists", variant: .secondary, size: .md, full: true,
                     icon: "text.bubble", loading: devBusy, enabled: !devBusy) {
                runDev { try await DevTools.generateResponses() }
            }
            GVButton("Reset onboarding", variant: .ghost, size: .md, full: true,
                     icon: "arrow.counterclockwise") {
                container.session.debugRestartOnboarding()
            }

            if let devStatus {
                Text(devStatus)
                    .font(Theme.label)
                    .foregroundStyle(Theme.textMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.x5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous).strokeBorder(Theme.border, lineWidth: 1))
    }

    /// Run a dev RPC with busy/status feedback. After data changes, refresh the
    /// settings header so counts/profile reflect the new state.
    private func runDev(_ op: @escaping () async throws -> String) {
        devBusy = true
        devStatus = nil
        Task {
            do { devStatus = try await op() }
            catch { devStatus = "Error: \(error.localizedDescription)" }
            devBusy = false
        }
    }
    #endif

    // MARK: - Danger zone

    private var dangerZone: some View {
        VStack(spacing: Theme.Space.x4) {
            GVButton("Sign out", variant: .secondary, full: true, icon: "rectangle.portrait.and.arrow.right") {
                pendingConfirm = GVConfirm(
                    title: "Sign out?",
                    message: "You can sign back in anytime.",
                    confirmTitle: "Sign out",
                    destructive: false
                ) { Task { await container.session.signOut() } }
            }

            Button {
                pendingConfirm = GVConfirm(
                    title: "Delete your account?",
                    message: "This permanently removes your profile, posts, and the replies others wrote about you. This can't be undone.",
                    confirmTitle: "Delete account",
                    destructive: true
                ) { Task { try? await container.session.deleteAccount() } }
            } label: {
                Text("Delete account")
                    .font(BrandFont.hanken(15, .bold))
                    .foregroundStyle(Theme.danger)
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.controlMd)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, Theme.Space.x2)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("GRAPEVINE · V1.0.0 (24)")
            .font(BrandFont.mono(11, .bold))
            .tracking(1.2)
            .foregroundStyle(Theme.textFaint)
            .padding(.top, Theme.Space.x4)
    }

    // MARK: - Section scaffold

    @ViewBuilder
    private func section<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text(title).gvKicker()
                .padding(.leading, Theme.Space.x2)
            GVCard(padding: 0) {
                VStack(spacing: 0) { content() }
            }
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.leading, Theme.Space.x6 + 28 + Theme.Space.x4)
    }

    // MARK: - Data

    private func load() async {
        if let id = container.auth.currentUserID {
            profile = try? await container.profile.fetch(id: id)
        }
        let blocked = (try? await container.connections.blockedIds()) ?? []
        blockedCount = blocked.count
    }
}

// MARK: - Reusable settings row

/// A tappable settings list row: leading icon chip, title (+ optional subtitle),
/// optional trailing accessory, chevron. Used inside the grouped GVCards.
private struct SettingsRow<Trailing: View>: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Theme.Space.x4) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.surface2)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BrandFont.hanken(16, .semibold))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(BrandFont.hanken(12, .regular))
                        .foregroundStyle(Theme.textFaint)
                }
            }

            Spacer(minLength: Theme.Space.x3)

            trailing()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x5)
        .contentShape(Rectangle())
    }
}

extension SettingsRow where Trailing == EmptyView {
    init(icon: String, title: String, subtitle: String? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// "PHONE PENDING" pill — the only verification state we can attest to today.
private struct VerificationBadge: View {
    let verified: Bool

    var body: some View {
        let label = verified ? "PHONE VERIFIED" : "PHONE PENDING"
        let color = verified ? Theme.success : Theme.warning
        Text(label)
            .font(BrandFont.mono(10, .bold))
            .tracking(0.6)
            .foregroundStyle(color)
            .padding(.horizontal, Theme.Space.x3)
            .padding(.vertical, 5)
            .background(color.opacity(0.16), in: Capsule())
    }
}

// =============================================================================
// EditProfileView — name / bio / IG handle editor + verification rows.
//
// Saves via `container.profile.upsert(...)`, reusing the exact signature
// ProfileSetupViewModel relies on: dob + ageVerified are preserved from the
// existing record (the user already passed the 18+ gate), so this never
// downgrades age attestation.
// =============================================================================

struct EditProfileView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    let profile: UserProfile?

    @State private var displayName: String
    @State private var bio: String
    @State private var igHandle: String
    @State private var busy = false
    @State private var error: String?

    init(profile: UserProfile?) {
        self.profile = profile
        _displayName = State(initialValue: profile?.displayName ?? "")
        _bio = State(initialValue: profile?.bio ?? "")
        _igHandle = State(initialValue: profile?.igHandle ?? "")
    }

    private var nameInvalid: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x7) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Display name").gvKicker()
                    GVInput("Your name", text: $displayName, maxLength: 40, leadingIcon: "person", invalid: nameInvalid && !displayName.isEmpty)
                }

                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Bio").gvKicker()
                    GVInput("A line about you (optional)", text: $bio, multiline: true, minHeight: 96, maxLength: 160)
                }

                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Instagram").gvKicker()
                    GVInput("@handle (optional)", text: $igHandle, maxLength: 30, leadingIcon: "camera")
                }

                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("Verification").gvKicker()
                    GVCard(padding: 0) {
                        VStack(spacing: 0) {
                            verificationRow(
                                icon: "phone",
                                title: "Phone",
                                verified: profile?.verifiedPhone ?? false,
                                pendingNote: "Pending"
                            )
                            Rectangle().fill(Theme.divider).frame(height: 1)
                                .padding(.leading, Theme.Space.x6 + 28 + Theme.Space.x4)
                            verificationRow(
                                icon: "calendar",
                                title: "Age (18+)",
                                verified: profile?.ageVerified ?? false,
                                pendingNote: "Not attested"
                            )
                        }
                    }
                }

                if let error {
                    Text(error)
                        .font(Theme.body)
                        .foregroundStyle(Theme.danger)
                }

                GVButton(
                    "Save changes",
                    variant: .primary,
                    full: true,
                    loading: busy,
                    enabled: !nameInvalid
                ) {
                    Task { await save() }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Edit profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func verificationRow(icon: String, title: String, verified: Bool, pendingNote: String) -> some View {
        HStack(spacing: Theme.Space.x4) {
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(Theme.surface2)
                    .frame(width: 28, height: 28)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.textMuted)
            }
            Text(title)
                .font(BrandFont.hanken(16, .semibold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: Theme.Space.x3)
            HStack(spacing: 5) {
                Image(systemName: verified ? "checkmark.seal.fill" : "clock")
                    .font(.system(size: 12, weight: .bold))
                Text(verified ? "Verified" : pendingNote)
                    .font(BrandFont.mono(11, .bold))
            }
            .foregroundStyle(verified ? Theme.success : Theme.textFaint)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x5)
    }

    private func save() async {
        guard let uid = container.auth.currentUserID else {
            error = "Not signed in."
            return
        }
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            error = "Pick a display name."
            return
        }
        busy = true
        error = nil
        defer { busy = false }
        do {
            let handle = igHandle.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "@", with: "")
            try await container.profile.upsert(
                id: uid,
                displayName: name,
                bio: bio.isEmpty ? nil : bio,
                igHandle: handle.isEmpty ? nil : handle,
                // Preserve what's already on record — the user passed the age gate
                // during onboarding; editing the profile never re-asks or downgrades it.
                dob: profile?.dob,
                ageVerified: profile?.ageVerified ?? true
            )
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// =============================================================================
// VerificationView — read-only status of the account's verifications.
// Pushed from the ACCOUNT · Verification row. Phone OTP isn't wired into
// onboarding yet, so phone shows PENDING; age reflects the gate attestation.
// =============================================================================

struct VerificationView: View {
    let profile: UserProfile?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                GVCard(padding: 0) {
                    VStack(spacing: 0) {
                        statusRow(
                            icon: "phone.fill",
                            title: "Phone number",
                            detail: "Verifying your phone keeps Grapevine real-people-only.",
                            verified: profile?.verifiedPhone ?? false,
                            pending: "Pending"
                        )
                        Rectangle().fill(Theme.divider).frame(height: 1)
                        statusRow(
                            icon: "calendar",
                            title: "Age (18+)",
                            detail: "Attested at sign-up via the age gate.",
                            verified: profile?.ageVerified ?? false,
                            pending: "Not attested"
                        )
                    }
                }

                if !(profile?.verifiedPhone ?? false) {
                    NavigationLink {
                        PhoneVerifyView(onComplete: {})
                    } label: {
                        HStack(spacing: 9) {
                            Image(systemName: "checkmark.shield.fill").font(.system(size: 18, weight: .bold))
                            Text("Verify your phone").font(BrandFont.hanken(16, .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.controlLg)
                        .foregroundStyle(Theme.onIntrigue)
                        .background(Theme.intrigue, in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
                    }
                } else {
                    Text("Your phone is verified — you're all set.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                        .padding(.horizontal, Theme.Space.x2)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Verification")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func statusRow(icon: String, title: String, detail: String, verified: Bool, pending: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x4) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                HStack(spacing: Theme.Space.x3) {
                    Text(title)
                        .font(BrandFont.hanken(16, .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer(minLength: 0)
                    HStack(spacing: 5) {
                        Image(systemName: verified ? "checkmark.seal.fill" : "clock")
                            .font(.system(size: 12, weight: .bold))
                        Text(verified ? "VERIFIED" : pending.uppercased())
                            .font(BrandFont.mono(10, .bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(verified ? Theme.success : Theme.warning)
                }
                Text(detail)
                    .font(BrandFont.hanken(13, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.x6)
    }
}

// =============================================================================
// DefaultSpiceView — pick the standing comfort ceiling. Live: tapping a row
// persists immediately via `container.profile.setDefaultSpice(level:)`, then
// reports the refreshed profile back up so Settings re-renders its ToneTag.
// =============================================================================

struct DefaultSpiceView: View {
    @Environment(AppContainer.self) private var container

    let initial: Tone
    let onChange: (UserProfile?) -> Void

    @State private var selected: Tone
    @State private var busy = false
    @State private var error: String?

    /// Ordered from the gentlest to the spiciest ceiling.
    private let options: [Tone] = [.wholesome, .playful, .social, .spicy]

    init(initial: Tone, onChange: @escaping (UserProfile?) -> Void) {
        self.initial = initial
        self.onChange = onChange
        _selected = State(initialValue: initial)
    }

    private func blurb(_ tone: Tone) -> String {
        switch tone {
        case .wholesome: return "Kind, warm, keep-it-light prompts only."
        case .playful:   return "Lighthearted and fun, a little teasing."
        case .social:    return "The everyday mix — the default for most."
        case .spicy:     return "Bold, revealing, no-holds-barred prompts."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x5) {
                Text("This is your ceiling. You'll never get prompts spicier than this — you can always go lower per prompt.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
                    .padding(.horizontal, Theme.Space.x2)

                GVCard(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(options.enumerated()), id: \.element) { index, tone in
                            Button {
                                Task { await pick(tone) }
                            } label: {
                                spiceRow(tone)
                            }
                            .buttonStyle(.plain)
                            .disabled(busy)

                            if index < options.count - 1 {
                                Rectangle().fill(Theme.divider).frame(height: 1)
                                    .padding(.leading, Theme.Space.x6)
                            }
                        }
                    }
                }

                if let error {
                    Text(error)
                        .font(Theme.body)
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, Theme.Space.x2)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Default spice")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func spiceRow(_ tone: Tone) -> some View {
        let isSelected = selected == tone
        HStack(spacing: Theme.Space.x4) {
            ToneTag(tone, size: .sm)
            VStack(alignment: .leading, spacing: 1) {
                Text(tone.label)
                    .font(BrandFont.hanken(16, .semibold))
                    .foregroundStyle(Theme.text)
                Text(blurb(tone))
                    .font(BrandFont.hanken(12, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.x3)
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isSelected ? tone.color : Theme.borderStrong)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x5)
        .contentShape(Rectangle())
    }

    private func pick(_ tone: Tone) async {
        guard tone != selected, !busy else {
            if tone == selected { return }
            return
        }
        let previous = selected
        selected = tone           // optimistic — feels instant
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await container.profile.setDefaultSpice(level: tone.rawValue)
            if let id = container.auth.currentUserID {
                let refreshed = try? await container.profile.fetch(id: id)
                onChange(refreshed)
            }
        } catch {
            selected = previous     // roll back on failure
            self.error = error.localizedDescription
        }
    }
}

// =============================================================================
// NotificationPreferencesView — per-category opt-ins.
//
// Local @State only: there's no notification-preferences table yet, so these
// toggles are presentational (they won't crash, and they don't pretend to
// persist). The note reinforces the product promise: batched, never per-reply.
// =============================================================================

struct NotificationPreferencesView: View {
    @Environment(AppContainer.self) private var container
    @State private var gistReady = true
    @State private var gistEvolved = true
    @State private var madeReplier = true
    @State private var nudges = false
    @State private var loaded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                GVCard(padding: 0) {
                    VStack(spacing: 0) {
                        toggleRow("Your gist is ready", "When a post graduates and your portrait updates.", isOn: $gistReady, tint: Theme.primary)
                        divider
                        toggleRow("Your gist evolved", "When new replies reshape an existing gist.", isOn: $gistEvolved, tint: Theme.intrigue)
                        divider
                        toggleRow("Made a replier", "When someone adds you to answer prompts about them.", isOn: $madeReplier, tint: Tone.social.color)
                        divider
                        toggleRow("Gentle nudges", "Occasional reminders to weigh in on prompts.", isOn: $nudges, tint: Tone.playful.color)
                    }
                }

                GVCard {
                    HStack(alignment: .top, spacing: Theme.Space.x3) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.intrigue)
                        Text("We batch hard and never ping per reply. You'll hear from us when something is genuinely worth your attention.")
                            .font(BrandFont.hanken(13, .regular))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
        .onChange(of: gistReady)   { _, _ in persist() }
        .onChange(of: gistEvolved) { _, _ in persist() }
        .onChange(of: madeReplier) { _, _ in persist() }
        .onChange(of: nudges)      { _, _ in persist() }
    }

    private func load() async {
        if let prefs = try? await container.profile.notifPrefs() {
            gistReady   = prefs["gist_ready"]   ?? gistReady
            gistEvolved = prefs["gist_evolved"] ?? gistEvolved
            madeReplier = prefs["made_replier"] ?? madeReplier
            nudges      = prefs["nudges"]       ?? nudges
        }
        loaded = true
    }

    /// Persist all four toggles to users.notif_prefs (skip the initial load writes).
    private func persist() {
        guard loaded else { return }
        let prefs = ["gist_ready": gistReady, "gist_evolved": gistEvolved,
                     "made_replier": madeReplier, "nudges": nudges]
        Task { try? await container.profile.setNotifPrefs(prefs) }
    }

    private var divider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
            .padding(.leading, Theme.Space.x6)
    }

    @ViewBuilder
    private func toggleRow(_ title: String, _ subtitle: String, isOn: Binding<Bool>, tint: Color) -> some View {
        HStack(spacing: Theme.Space.x4) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandFont.hanken(16, .semibold))
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .font(BrandFont.hanken(12, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: Theme.Space.x4)
            GVSwitch(isOn: isOn, tint: tint)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x5)
    }
}

// =============================================================================
// BlockedUsersView — lists `connections.blockedIds()` resolved via
// `profile.fetchMany(ids:)`. Unblock calls `connections.unblock(userId:)` and
// drops the row. Empty + error states degrade gracefully.
// =============================================================================

struct BlockedUsersView: View {
    @Environment(AppContainer.self) private var container

    @State private var blocked: [UserProfile] = []
    @State private var blockedIds: [UUID] = []
    @State private var loading = true
    @State private var error: String?
    @State private var working: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x6) {
                if loading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.top, Theme.Space.x10)
                } else if blocked.isEmpty && blockedIds.isEmpty {
                    emptyState
                } else {
                    GVCard(padding: 0) {
                        VStack(spacing: 0) {
                            // Resolved profiles first; any ids we couldn't resolve still
                            // render so the user can unblock them (degrades gracefully).
                            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                                blockedRow(row)
                                if index < rows.count - 1 {
                                    Rectangle().fill(Theme.divider).frame(height: 1)
                                        .padding(.leading, Theme.Space.x6)
                                }
                            }
                        }
                    }
                }

                GVCard {
                    HStack(alignment: .top, spacing: Theme.Space.x3) {
                        Image(systemName: "hand.raised.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textMuted)
                        Text("Blocked people can't add you, see your prompts, or reply about you. Unblocking doesn't restore old replies.")
                            .font(BrandFont.hanken(13, .regular))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if let error {
                    Text(error)
                        .font(Theme.body)
                        .foregroundStyle(Theme.danger)
                        .padding(.horizontal, Theme.Space.x2)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("Blocked users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    /// One row per blocked id: a resolved profile when available, else a bare id.
    private struct Row: Identifiable {
        let id: UUID
        let profile: UserProfile?
    }

    private var rows: [Row] {
        blockedIds.map { id in
            Row(id: id, profile: blocked.first { $0.id == id })
        }
    }

    private var emptyState: some View {
        GVCard {
            VStack(alignment: .leading, spacing: Theme.Space.x2) {
                Text("No one blocked").gvKicker()
                Text("People you block will show up here so you can unblock them later.")
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
            }
        }
    }

    @ViewBuilder
    private func blockedRow(_ row: Row) -> some View {
        let name = (row.profile?.displayName?.isEmpty == false) ? row.profile!.displayName! : "Blocked user"
        let photo: URL? = {
            guard let s = row.profile?.photoURL, let url = URL(string: s) else { return nil }
            return url
        }()
        HStack(spacing: Theme.Space.x4) {
            GVAvatar(name: name, imageURL: photo, size: .md)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(BrandFont.hanken(16, .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if let h = row.profile?.igHandle, !h.isEmpty {
                    Text("@\(h)")
                        .font(BrandFont.mono(11, .regular))
                        .foregroundStyle(Theme.textFaint)
                }
            }
            Spacer(minLength: Theme.Space.x3)
            GVButton(
                "Unblock",
                variant: .secondary,
                size: .sm,
                loading: working.contains(row.id)
            ) {
                Task { await unblock(row.id) }
            }
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x4)
    }

    private func load() async {
        loading = true
        error = nil
        do {
            let ids = try await container.connections.blockedIds()
            blockedIds = ids
            blocked = ids.isEmpty ? [] : (try await container.profile.fetchMany(ids: ids))
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }

    private func unblock(_ id: UUID) async {
        working.insert(id)
        defer { working.remove(id) }
        do {
            try await container.connections.unblock(userId: id)
            blockedIds.removeAll { $0 == id }
            blocked.removeAll { $0.id == id }
        } catch {
            self.error = error.localizedDescription
        }
    }
}

// =============================================================================
// AboutView — wordmark, the one-liner, links, modest moderation copy, version.
// Links are presentational placeholders until the marketing/legal URLs exist.
// =============================================================================

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x7) {
                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Wordmark(size: 32, withMark: true)
                    Text("Your friends decide who you are. Answer prompts about each other; once enough people weigh in, a gist graduates into a crowd-authored portrait.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("How it works").gvKicker()
                    GVCard(padding: 0) {
                        VStack(spacing: 0) {
                            step(1, "Add friends.", "They become repliers — people who can answer prompts about you.")
                            stepDivider
                            step(2, "Answer the daily prompt.", "About the people you've connected with. It stays blind until it graduates.")
                            stepDivider
                            step(3, "A gist graduates.", "Once enough replies land, the crowd's take becomes your portrait — and it evolves over time.")
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Space.x3) {
                    Text("More").gvKicker()
                    GVCard(padding: 0) {
                        VStack(spacing: 0) {
                            linkRow("Community guidelines", "doc.text")
                            linkDivider
                            linkRow("Terms of service", "doc.plaintext")
                            linkDivider
                            linkRow("Privacy policy", "lock.shield")
                        }
                    }
                }

                GVCard {
                    HStack(alignment: .top, spacing: Theme.Space.x3) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.success)
                        Text("We keep it kind. Replies are about real people, so harassment, hate, and doxxing aren't allowed — you can block or report anyone, anytime. We review reports and remove what crosses the line.")
                            .font(BrandFont.hanken(13, .regular))
                            .foregroundStyle(Theme.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Text("GRAPEVINE · V1.0.0 (24)")
                    .font(BrandFont.mono(11, .bold))
                    .tracking(1.2)
                    .foregroundStyle(Theme.textFaint)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x5)
            .padding(.bottom, Theme.Space.x12)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func step(_ n: Int, _ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Space.x4) {
            ZStack {
                Circle().fill(Theme.primarySoft).frame(width: 28, height: 28)
                Text("\(n)")
                    .font(BrandFont.mono(13, .bold))
                    .foregroundStyle(Theme.primary)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(BrandFont.hanken(15, .bold))
                    .foregroundStyle(Theme.text)
                Text(body)
                    .font(BrandFont.hanken(13, .regular))
                    .foregroundStyle(Theme.textFaint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(Theme.Space.x6)
    }

    private var stepDivider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
            .padding(.leading, Theme.Space.x6 + 28 + Theme.Space.x4)
    }

    @ViewBuilder
    private func linkRow(_ title: String, _ icon: String) -> some View {
        HStack(spacing: Theme.Space.x4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.textMuted)
                .frame(width: 24)
            Text(title)
                .font(BrandFont.hanken(16, .semibold))
                .foregroundStyle(Theme.text)
            Spacer(minLength: 0)
            Image(systemName: "arrow.up.right")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.textFaint)
        }
        .padding(.horizontal, Theme.Space.x6)
        .padding(.vertical, Theme.Space.x5)
        .contentShape(Rectangle())
    }

    private var linkDivider: some View {
        Rectangle().fill(Theme.divider).frame(height: 1)
            .padding(.leading, Theme.Space.x6 + 24 + Theme.Space.x4)
    }
}

#if DEBUG
/// Dev-only bridge to the seeding RPCs in migration 0010_dev_seed.sql. These run
/// as the signed-in user and only touch dev data; remove before production.
enum DevTools {
    static func seedFriends() async throws -> Int {
        try await SupabaseClientProvider.shared.rpc("dev_seed_friends").execute().value
    }
    static func generateResponses() async throws -> String {
        try await SupabaseClientProvider.shared.rpc("dev_generate_responses").execute().value
    }
}
#endif
