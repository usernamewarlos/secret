import SwiftUI

struct AnswerView: View {
    let prompt: Prompt
    let owner: UserProfile
    var count: Int = 0
    var threshold: Int = 0
    var onSubmitted: () -> Void

    /// Live graduation line for the target's post (replaces the old hardcoded "8 / 10").
    private var graduationLine: String {
        guard threshold > 0 else { return "Your reply joins the blind pile." }
        if count + 1 >= threshold {
            return "\(count) / \(threshold) · your reply could graduate it 👀"
        }
        return "\(count) / \(threshold) · keep it accumulating"
    }

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var vm: AnswerViewModel?

    private var ownerFirstName: String {
        (owner.displayName ?? "your friend")
            .split(separator: " ")
            .first
            .map(String.init) ?? (owner.displayName ?? "your friend")
    }

    var body: some View {
        Group {
            if let vm {
                sheet(vm)
            } else {
                ProgressView()
                    .tint(Theme.primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.bg)
            }
        }
        .onAppear {
            if vm == nil {
                vm = AnswerViewModel(replies: container.replies, prompt: prompt, owner: owner)
            }
        }
    }

    // MARK: - Sheet

    @ViewBuilder
    private func sheet(_ viewModel: AnswerViewModel) -> some View {
        @Bindable var vm = viewModel

        ScrollView {
            VStack(spacing: 0) {
                // Grab handle.
                Capsule()
                    .fill(Theme.borderStrong)
                    .frame(width: 40, height: 5)
                    .padding(.top, Theme.Space.x3)
                    .padding(.bottom, Theme.Space.x4)

                VStack(alignment: .leading, spacing: Theme.Space.x5) {
                    header

                    // Echoed prompt in a sunken card.
                    promptEcho

                    // Reply input.
                    GVInput(
                        "Keep it punchy and fond…",
                        text: $vm.body,
                        multiline: true,
                        minHeight: 120,
                        maxLength: AnswerViewModel.maxLength,
                        invalid: vm.isOverLimit
                    )

                    // Public / Private segmented toggle.
                    privacyToggle(vm)

                    // Privacy note.
                    Text("Private replies are yours alone — even \(ownerFirstName) can't read them. No edits after you send.")
                        .font(BrandFont.mono(10.5, .regular))
                        .tracking(0.3)
                        .lineSpacing(3)
                        .foregroundStyle(Theme.textFaint)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    if let error = vm.error {
                        Text(error)
                            .font(Theme.label)
                            .foregroundStyle(Theme.danger)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Send button.
                    GVButton(
                        "Send your reply",
                        size: .lg,
                        full: true,
                        icon: "paperplane.fill",
                        loading: vm.busy,
                        enabled: vm.canSubmit
                    ) {
                        Task {
                            if await vm.submit() {
                                onSubmitted()
                                dismiss()
                            }
                        }
                    }
                }
                .padding(.horizontal, Theme.Space.x6)
                .padding(.bottom, Theme.Space.x8)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.bgElevated)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Theme.Space.x3) {
            GVAvatar(name: owner.displayName, size: .lg, ring: true)

            VStack(alignment: .leading, spacing: 2) {
                Text("Answer about \(ownerFirstName)")
                    .font(BrandFont.hanken(19, .heavy))
                    .tracking(-0.4)
                    .foregroundStyle(Theme.text)

                Text(graduationLine)
                    .font(Theme.body)
                    .foregroundStyle(Theme.textMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ToneTag(Tone(prompt.tone), size: .sm)
        }
    }

    // MARK: - Echoed prompt

    private var promptEcho: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("TODAY'S PROMPT")
                .font(BrandFont.mono(10, .bold))
                .tracking(1.4)
                .foregroundStyle(Theme.textFaint)

            Text(prompt.text)
                .font(BrandFont.hanken(19, .bold))
                .tracking(-0.4)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(Theme.surfaceSunken, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    // MARK: - Public / Private toggle

    @ViewBuilder
    private func privacyToggle(_ vm: AnswerViewModel) -> some View {
        HStack(spacing: Theme.Space.x2) {
            privacyOption(
                label: "Public",
                icon: "globe",
                tint: Theme.primary,
                tintSoft: Theme.primarySoft,
                active: !vm.isPrivate
            ) {
                withAnimation(Theme.Motion.easeOut) { vm.isPrivate = false }
            }

            privacyOption(
                label: "Private",
                icon: "lock.fill",
                tint: Theme.intrigue,
                tintSoft: Theme.intrigueSoft,
                active: vm.isPrivate
            ) {
                withAnimation(Theme.Motion.easeOut) { vm.isPrivate = true }
            }
        }
        .padding(4)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous))
    }

    @ViewBuilder
    private func privacyOption(
        label: String,
        icon: String,
        tint: Color,
        tintSoft: Color,
        active: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Space.x2) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(label)
                    .font(BrandFont.hanken(14, .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .foregroundStyle(active ? tint : Theme.textMuted)
            .background(active ? tintSoft : Color.clear, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .strokeBorder(active ? tint : Color.clear, lineWidth: 1.5)
            )
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
