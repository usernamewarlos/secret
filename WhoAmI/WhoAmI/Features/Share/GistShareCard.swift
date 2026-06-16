import SwiftUI

/// The screenshot-ready share artifact (docs/PRODUCT.md §6.10). Fixed size so it renders
/// crisply via ImageRenderer regardless of device.
struct GistShareCard: View {
    let verdict: String
    let text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GRAPEVINE")
                .font(.caption.weight(.black))
                .tracking(3)
                .foregroundStyle(.white.opacity(0.85))

            Spacer(minLength: 0)

            Text(verdict)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Text(text)
                .font(.body)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(7)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(prompt)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))

            Text("who your friends say you are")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(28)
        .frame(width: 360, height: 480, alignment: .leading)
        .background(
            LinearGradient(colors: [Color(red: 0.45, green: 0.18, blue: 0.85),
                                    Color(red: 0.93, green: 0.18, blue: 0.45)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28))
    }
}
