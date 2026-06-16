import SwiftUI

struct AgeGateView: View {
    /// Called once the user clears the 18+ gate, surfacing the chosen DOB so it can be
    /// threaded into profile setup (`age_verified` then reflects a real gate pass).
    let onPass: (_ dob: Date) -> Void
    @State private var vm = AgeGateViewModel()

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("How old are you?")
                .font(.largeTitle.bold())
            Text("Grapevine is for ages 18 and up.")
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
                    onPass(vm.dob)
                } else {
                    vm.error = "You must be 18 or older to use Grapevine."
                }
            }
            Spacer()
        }
        .padding()
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }
}
