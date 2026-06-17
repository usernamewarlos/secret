import SwiftUI

/// Profile setup — name, bio, and the spice-comfort ceiling. On save it hands off
/// to the mandatory invite gate via `onDone` (the coordinator routes from here).
struct ProfileSetupView: View {
    /// Called once the profile is saved — the coordinator advances to the invite gate.
    var onDone: () -> Void

    @Environment(AppContainer.self) private var container
    @State private var vm: ProfileSetupViewModel?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let vm {
                form(vm)
            } else {
                ProgressView().tint(Theme.primary)
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
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x7) {
                VStack(alignment: .leading, spacing: Theme.Space.x2) {
                    Text("Set up your profile")
                        .font(Theme.display)
                        .foregroundStyle(Theme.text)
                    Text("It starts empty — that's the point.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.textMuted)
                }
                .padding(.top, Theme.Space.x6)

                avatar(vm)
                    .frame(maxWidth: .infinity)

                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    fieldLabel("Display name")
                    GVInput("Your name", text: $vm.displayName)

                    fieldLabel("Bio")
                    GVInput("A line about you (optional)", text: $vm.bio, multiline: true, minHeight: 84, maxLength: 120)

                    fieldLabel("Instagram (optional)")
                    GVInput("@handle", text: $vm.igHandle, leadingIcon: "at")
                }

                VStack(alignment: .leading, spacing: Theme.Space.x4) {
                    Text("Spice comfort").gvKicker()
                    Text("The hottest tone friends can post about you. You can change it anytime.")
                        .font(Theme.label)
                        .foregroundStyle(Theme.textMuted)
                    ForEach(ProfileSetupViewModel.SpiceLevel.allCases) { level in
                        spiceRow(level, selected: vm.defaultSpice == level) {
                            vm.defaultSpice = level
                        }
                    }
                }

                if let error = vm.error {
                    Text(error).font(Theme.label).foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.bottom, Theme.Space.x8)
        }
        .scrollDismissesKeyboard(.interactively)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                Divider().background(Theme.border)
                GVButton(vm.busy ? "Saving…" : "Next: add friends",
                         full: true, loading: vm.busy, enabled: !vm.busy) {
                    Task {
                        if await vm.save() { onDone() }
                    }
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, Theme.Space.x4)
                .padding(.bottom, Theme.Space.x9)
            }
            .background(.ultraThinMaterial)
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(BrandFont.hanken(13, .semibold))
            .foregroundStyle(Theme.textMuted)
    }

    private func avatar(_ vm: ProfileSetupViewModel) -> some View {
        GVAvatar(name: vm.displayName.isEmpty ? nil : vm.displayName, size: .xl)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 30, height: 30)
                    .overlay {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Theme.onPrimary)
                    }
                    .overlay(Circle().strokeBorder(Theme.bg, lineWidth: 3))
            }
    }

    private func spiceRow(_ level: ProfileSetupViewModel.SpiceLevel, selected: Bool, action: @escaping () -> Void) -> some View {
        let tone = Tone(spice: level.rawValue)
        return Button(action: action) {
            HStack(spacing: Theme.Space.x4) {
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(selected ? Color.white.opacity(0.22) : tone.soft)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: tone.symbol)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(selected ? .white : tone.color)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(level.label)
                        .font(BrandFont.hanken(16, .bold))
                        .foregroundStyle(selected ? .white : Theme.text)
                    Text(spiceDesc(level))
                        .font(Theme.label)
                        .foregroundStyle(selected ? Color.white.opacity(0.85) : Theme.textMuted)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(Theme.Space.x4)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(selected ? tone.color : Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(selected ? Color.clear : Theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func spiceDesc(_ level: ProfileSetupViewModel.SpiceLevel) -> String {
        switch level {
        case .wholesome: return "Warm and kind — keep it sweet."
        case .playful:   return "Fun and lighthearted."
        case .social:    return "Honest and balanced."
        case .spicy:     return "Bring the heat — roasts on."
        }
    }
}
