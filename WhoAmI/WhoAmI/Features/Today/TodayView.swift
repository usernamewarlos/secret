import SwiftUI

struct TodayView: View {
    @Environment(AppContainer.self) private var container
    @State private var vm: TodayViewModel?
    @State private var answerTarget: TodayViewModel.Target?

    var body: some View {
        NavigationStack {
            Group {
                if let vm {
                    content(vm)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Today")
            .onAppear {
                if vm == nil {
                    let model = TodayViewModel(
                        prompts: container.prompts,
                        connections: container.connections,
                        posts: container.posts,
                        replies: container.replies
                    )
                    vm = model
                    Task { await model.load() }
                }
            }
            .refreshable { await vm?.load() }
            .sheet(item: $answerTarget) { target in
                if let prompt = vm?.prompt {
                    AnswerView(prompt: prompt, owner: target.owner) {
                        vm?.markAnswered(target.owner.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ vm: TodayViewModel) -> some View {
        if let prompt = vm.prompt {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(prompt.tone.rawValue.capitalized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(prompt.text)
                            .font(.title3.bold())
                    }
                    .padding(.vertical, 4)
                }

                Section("Answer about") {
                    if vm.targets.isEmpty {
                        Text("No one has made you a replier yet. Add people in the People tab — they decide who can write about them.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(vm.targets) { target in
                        Button {
                            answerTarget = target
                        } label: {
                            HStack {
                                Text(target.owner.displayName ?? "Someone")
                                    .foregroundStyle(target.answered ? .secondary : .primary)
                                Spacer()
                                if target.answered {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .foregroundStyle(.tertiary)
                                }
                            }
                        }
                        .disabled(target.answered)
                    }
                }

                if let error = vm.error {
                    Text(error).foregroundStyle(.red)
                }
            }
        } else if vm.loading {
            ProgressView()
        } else {
            ContentUnavailableView(
                "No prompt today",
                systemImage: "calendar",
                description: Text("Today's prompt hasn't been published yet.")
            )
        }
    }
}
