import SwiftUI

struct AgeGateView: View {
    /// Called once the user clears the 18+ gate, surfacing the chosen DOB so it can be
    /// threaded into profile setup (`age_verified` then reflects a real gate pass).
    let onPass: (_ dob: Date) -> Void
    @State private var vm = AgeGateViewModel()

    /// Whole-year age for the wholesome confirmation chip ("YOU'RE NN · GOOD TO GO").
    private var age: Int {
        Calendar.current.dateComponents([.year], from: vm.dob, to: Date()).year ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Cake icon tile
            ZStack {
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.surface2)
                Image(systemName: "birthday.cake.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Theme.text)
            }
            .frame(width: 60, height: 60)
            .padding(.bottom, Theme.Space.x7)

            // Heading
            Text("When's your birthday?")
                .font(Theme.display)
                .foregroundStyle(Theme.text)
                .padding(.bottom, Theme.Space.x4)

            // Subhead
            Text("Grapevine is 18+. We ask for your date of birth — not a yes / no.")
                .font(Theme.body)
                .foregroundStyle(Theme.textMuted)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, Theme.Space.x7)

            // DOB entry — preserved wheel picker, themed for the dark surface
            DatePicker(
                "Date of birth",
                selection: $vm.dob,
                in: ...Date(),
                displayedComponents: .date
            )
            .datePickerStyle(.wheel)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .tint(Theme.primary)
            .padding(.horizontal, Theme.Space.x4)
            .padding(.vertical, Theme.Space.x2)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .strokeBorder(Theme.borderStrong, lineWidth: 1.5)
            )
            .padding(.bottom, Theme.Space.x5)

            // Wholesome confirmation chip — only when eligible
            if vm.isEligible() {
                HStack(spacing: Theme.Space.x3) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text("YOU'RE \(age) · GOOD TO GO")
                        .font(BrandFont.mono(11, .bold))
                        .tracking(11 * 0.06)
                }
                .foregroundStyle(Tone.wholesome.color)
                .padding(.horizontal, Theme.Space.x4)
                .padding(.vertical, 11)
                .background(Tone.wholesome.soft, in: RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous))
            } else if let error = vm.error {
                Text(error)
                    .font(Theme.body)
                    .foregroundStyle(Theme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: Theme.Space.x6)

            // Mono privacy note
            Text("We store only that you passed, never your full DOB.")
                .font(BrandFont.mono(11, .regular))
                .tracking(11 * 0.04)
                .foregroundStyle(Theme.textFaint)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, Theme.Space.x5)

            // Continue — primary, full-width, gated on eligibility
            GVButton("Continue", size: .lg, full: true, enabled: vm.isEligible()) {
                if vm.isEligible() {
                    onPass(vm.dob)
                } else {
                    vm.error = "You must be 18 or older to use Grapevine."
                }
            }
        }
        .padding(.horizontal, Theme.gutter)
        .padding(.top, Theme.Space.x8)
        .padding(.bottom, Theme.Space.x6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarBackButtonHidden(false)
    }
}
