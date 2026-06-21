import SwiftUI

/// Today — the daily loop under per-profile prompt rotation. Shows the prompt your
/// friends are answering about YOU today (shaped by your spice level), a spice
/// control that reshapes it, and the people you can answer about — each on their
/// own rotated prompt.
struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: TodayViewModel?
    @State private var answerTarget: TodayTarget?
    @State private var toast: String?

    private let spiceLevels = ["wholesome", "playful", "social", "spicy"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if let vm {
                    content(vm)
                } else {
                    ProgressView().tint(Theme.primary)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear {
                if vm == nil {
                    let model = TodayViewModel(
                        prompts: container.prompts,
                        profile: container.profile,
                        auth: container.auth
                    )
                    vm = model
                    Task { await model.load() }
                }
            }
            .refreshable { await vm?.load() }
            .sheet(item: $answerTarget) { target in
                if let vm {
                    AnswerView(prompt: vm.prompt(for: target), owner: vm.owner(for: target),
                               count: target.count, threshold: target.threshold) {
                        vm.markAnswered(target.ownerId)
                        toast = "Reply sent ✓"
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.hidden)
                }
            }
            .overlay(alignment: .bottom) {
                if let toast {
                    Text(toast)
                        .font(BrandFont.hanken(14, .bold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, Theme.Space.x5)
                        .padding(.vertical, Theme.Space.x3)
                        .background(Capsule().fill(Theme.surface2))
                        .overlay(Capsule().strokeBorder(Theme.border, lineWidth: 1))
                        .padding(.bottom, Theme.Space.x6)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            self.toast = nil
                        }
                }
            }
            .animation(Theme.Motion.spring, value: toast)
        }
    }

    @ViewBuilder
    private func content(_ vm: TodayViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.x7) {
                header

                if let mine = vm.myPrompt {
                    aboutYou(vm, mine)
                }

                spiceControl(vm)

                answerList(vm)

                if let error = vm.error {
                    Text(error).font(Theme.label).foregroundStyle(Theme.danger)
                }
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x4)
            .padding(.bottom, Theme.Space.x10)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Wordmark(size: 22, withMark: true)
            Spacer()
            HStack(spacing: Theme.Space.x2) {
                Image(systemName: "flame.fill").font(.system(size: 13, weight: .bold))
                Text("7").font(BrandFont.mono(13, .bold))
            }
            .foregroundStyle(Theme.primary)
            .padding(.horizontal, Theme.Space.x4)
            .padding(.vertical, Theme.Space.x2)
            .background(Capsule().fill(Theme.primarySoft))
        }
        .padding(.top, Theme.Space.x4)
    }

    // MARK: - Your prompt today

    @ViewBuilder
    private func aboutYou(_ vm: TodayViewModel, _ mine: TodayFeed.MyPrompt) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text("What friends answer about you today").gvKicker()
            PromptCard(prompt: mine.text, tone: Tone(mine.tone), kicker: "TODAY · ABOUT YOU") {
                if let feed = vm.feed {
                    GVCounter(count: feed.myCount, threshold: feed.myThreshold, size: .sm)
                }
            }
        }
    }

    // MARK: - Spice control (reshapes your rotation)

    @ViewBuilder
    private func spiceControl(_ vm: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x3) {
            Text("Your spice level").gvKicker()
            Text("Sets how hot the prompts about you can get.")
                .font(Theme.label).foregroundStyle(Theme.textMuted)
            HStack(spacing: Theme.Space.x2) {
                ForEach(spiceLevels, id: \.self) { level in
                    let tone = Tone(spice: level)
                    let active = vm.myLevel == level
                    Button {
                        Task { await vm.setSpice(level) }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: tone.symbol).font(.system(size: 12, weight: .bold))
                            Text(tone.label).font(BrandFont.hanken(12.5, .bold))
                        }
                        .foregroundStyle(active ? .white : tone.color)
                        .padding(.horizontal, Theme.Space.x3)
                        .frame(height: 34)
                        .frame(maxWidth: .infinity)
                        .background(Capsule().fill(active ? tone.color : tone.soft))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.spiceBusy)
                }
            }
        }
    }

    // MARK: - Answer about your people

    @ViewBuilder
    private func answerList(_ vm: TodayViewModel) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.x4) {
            Text("Answer about your people").gvKicker()

            if vm.targets.isEmpty {
                GVCard {
                    Text("No one has made you a replier yet. Add people in the People tab — they choose who can write about them.")
                        .font(Theme.body).foregroundStyle(Theme.textMuted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(vm.targets) { target in
                    targetCard(target)
                }
            }
        }
    }

    private func targetCard(_ t: TodayTarget) -> some View {
        GVCard(padding: Theme.Space.x5) {
            VStack(alignment: .leading, spacing: Theme.Space.x4) {
                HStack(spacing: Theme.Space.x4) {
                    GVAvatar(name: t.name, size: .md)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(t.name ?? "Someone")
                            .font(BrandFont.hanken(16, .bold))
                            .foregroundStyle(t.answered ? Theme.textMuted : Theme.text)
                        ToneTag(Tone(t.promptTone), size: .sm)
                    }
                    Spacer(minLength: Theme.Space.x3)
                    GVCounter(count: t.count, threshold: t.threshold, size: .sm, showLabel: false)
                }

                Text(t.promptText)
                    .font(BrandFont.hanken(17, .semibold))
                    .foregroundStyle(t.answered ? Theme.textMuted : Theme.text)
                    .fixedSize(horizontal: false, vertical: true)

                if t.answered {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 15, weight: .bold))
                        Text("Answered").font(Theme.label)
                    }
                    .foregroundStyle(Tone.wholesome.color)
                } else {
                    GVButton("Answer", variant: .primary, size: .sm, icon: "pencil.line") {
                        answerTarget = t
                    }
                }
            }
        }
        .opacity(t.answered ? 0.7 : 1)
    }
}
