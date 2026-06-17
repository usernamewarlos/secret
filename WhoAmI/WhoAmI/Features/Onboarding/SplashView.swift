import SwiftUI

/// The very first screen on launch — a branded Grapevine moment that hands off to the
/// session-driven routing once it's done.
struct SplashView: View {
    var onFinished: () -> Void

    /// Drives the one-shot fade/scale entrance.
    @State private var appear = false
    /// Drives the continuous gentle float of the mark.
    @State private var float = false
    /// Drives the bottom spinner rotation.
    @State private var spin = false

    var body: some View {
        ZStack {
            // Grape → tangerine radial glow over warm near-black. White text regardless of theme.
            BrandSplashBackground()

            VStack(spacing: Theme.Space.x7) {
                Spacer()

                // The voices cluster, drifting on a soft loop with a grape glow.
                GrapeMark(size: 120)
                    .scaleEffect(appear ? 1 : 0.82)
                    .offset(y: float ? -8 : 8)
                    .gvShadow(Theme.glowGrape)

                VStack(spacing: Theme.Space.x2) {
                    Wordmark(size: 46, color: .white)

                    Text("Heard it through the grapevine")
                        .gvKicker(.white.opacity(0.7))
                }

                Spacer()

                // Small indeterminate spinner near the bottom.
                Circle()
                    .trim(from: 0, to: 0.82)
                    .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: 34, height: 34)
                    .opacity(0.92)
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .padding(.bottom, Theme.Space.x12)
            }
            .opacity(appear ? 1 : 0)
        }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appear = true }
            withAnimation(.easeInOut(duration: 3.4).repeatForever(autoreverses: true)) { float = true }
            withAnimation(.linear(duration: 0.8).repeatForever(autoreverses: false)) { spin = true }
            try? await Task.sleep(nanoseconds: 1_800_000_000)
            onFinished()
        }
    }
}
