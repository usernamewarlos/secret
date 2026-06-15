import SwiftUI

struct AgeGateView: View {
    let onPass: () -> Void
    @State private var vm = AgeGateViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How old are you?")
                .font(.largeTitle.bold())
            Text("Who Am I is for ages 18 and up.")
                .foregroundStyle(.secondary)

            DatePicker(
                "Date of birth",
                selection: $vm.dob,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()

            if let error = vm.error {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            PrimaryButton(title: "Continue") {
                if vm.isEligible() {
                    onPass()
                } else {
                    vm.error = "You must be 18 or older to use Who Am I."
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }
}
