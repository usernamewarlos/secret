import SwiftUI

/// Previews the share-card and offers a system ShareLink for the rendered image.
struct GistShareView: View {
    let verdict: String
    let text: String
    let prompt: String

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                GistShareCard(verdict: verdict, text: text, prompt: prompt)
                    .shadow(radius: 12, y: 6)

                if let rendered {
                    ShareLink(item: rendered, preview: SharePreview("My gist", image: rendered)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius))
                    .padding(.horizontal)
                } else {
                    ProgressView()
                }
            }
            .padding()
            .navigationTitle("Share your gist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .onAppear(perform: render)
        }
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: GistShareCard(verdict: verdict, text: text, prompt: prompt))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            rendered = Image(uiImage: uiImage)
        }
    }
}
