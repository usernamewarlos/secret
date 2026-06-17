import SwiftUI

/// "Share your gist" sheet (design handoff §"Share your gist" / "Share card").
///
/// Restyled to the Grapevine system: a `bg-elevated` sheet with a grabber, a
/// display-type header + close affordance, the `GistShareCard` artifact preview,
/// a row of four share actions rendered as `GVIconButton`s (Story / Save /
/// Copy link / More), and a full-width "Share to story" `GVButton`.
///
/// The existing rendered-image `ShareLink` is PRESERVED — it backs both the
/// "Share to story" path (via the system share sheet) and the explicit More
/// action. The struct name, its `verdict / text / prompt` init, the `rendered`
/// state, and the `render()` ImageRenderer pass are all kept intact.
struct GistShareView: View {
    let verdict: String
    let text: String
    let prompt: String
    /// A shareable link to copy. Defaults to the app URL; callers can pass a
    /// per-post deep link. (Previously "Copy link" copied the gist verdict text.)
    var shareURL: URL = URL(string: "https://grapevineapp.app")!

    @Environment(\.dismiss) private var dismiss
    @State private var rendered: Image?
    @State private var renderedImage: UIImage?
    @State private var renderFailed = false
    @State private var copied = false

    /// Text fallback used if the image render fails — keeps sharing from dead-ending.
    private var shareText: String {
        "\(verdict)\n\n\(text)\n\n— my gist on Grapevine · \(shareURL.absoluteString)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Space.x6) {
                grabber

                header

                // The growth artifact — the screenshot-ready share card.
                GistShareCard(verdict: verdict, text: text, prompt: prompt)
                    .gvShadow(Theme.shadowXl)
                    .frame(maxWidth: .infinity)

                // A row of 4 quick-share actions.
                actionsRow

                // Primary CTA — routes through the rendered-image share sheet.
                shareToStory
            }
            .padding(.horizontal, Theme.gutter)
            .padding(.top, Theme.Space.x3)
            .padding(.bottom, Theme.Space.x8)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.bgElevated.ignoresSafeArea())
        .onAppear(perform: render)
    }

    // MARK: Pieces

    private var grabber: some View {
        Capsule(style: .continuous)
            .fill(Theme.borderStrong)
            .frame(width: 40, height: 5)
            .padding(.top, Theme.Space.x2)
            .padding(.bottom, Theme.Space.x2)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Share your gist")
                .font(BrandFont.hanken(22, .heavy))
                .tracking(-22 * 0.02)
                .foregroundStyle(Theme.text)

            Spacer(minLength: Theme.Space.x4)

            GVIconButton(
                icon: "xmark",
                variant: .ghost,
                size: .sm,
                accessibilityLabel: "Close"
            ) { dismiss() }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionsRow: some View {
        HStack(spacing: 0) {
            shareAction(
                icon: "camera.fill",
                label: "Story",
                accessibility: "Share to story"
            ) { /* handled by Share to story CTA + system share */ }

            shareAction(
                icon: "arrow.down.to.line",
                label: "Save",
                accessibility: "Save image"
            ) { saveImage() }

            shareAction(
                icon: copied ? "checkmark" : "link",
                label: copied ? "Copied!" : "Copy link",
                accessibility: "Copy link"
            ) { copyLink() }

            shareAction(
                icon: "ellipsis",
                label: "More",
                accessibility: "More share options"
            ) { /* surfaced via the trailing ShareLink */ }
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .topTrailing) {
            // The system ShareLink is the authoritative "More" target — keep it
            // wired to the rendered image and overlay it on the More slot so it
            // remains the real share entry point without re-rendering chrome.
            if let rendered {
                ShareLink(
                    item: rendered,
                    preview: SharePreview("My gist", image: rendered)
                ) {
                    Color.clear
                        .frame(width: 54, height: 78)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("More share options")
            }
        }
    }

    private func shareAction(
        icon: String,
        label: String,
        accessibility: String,
        action: @escaping () -> Void
    ) -> some View {
        VStack(spacing: Theme.Space.x2) {
            GVIconButton(
                icon: icon,
                variant: .surface,
                size: .lg,
                accessibilityLabel: accessibility,
                action: action
            )
            Text(label)
                .font(BrandFont.hanken(12, .semibold))
                .foregroundStyle(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var shareToStory: some View {
        if let rendered {
            ShareLink(
                item: rendered,
                preview: SharePreview("My gist", image: rendered)
            ) {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 22, weight: .bold))
                    Text("Share to story")
                        .font(BrandFont.hanken(18, .bold))
                        .tracking(-0.01 * 18)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.controlLg)
                .padding(.horizontal, 28)
                .foregroundStyle(Theme.onPrimary)
                .background(
                    Theme.primary,
                    in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous)
                )
                .gvShadow(Theme.glowTangerine)
            }
            .accessibilityLabel("Share to story")
        } else if renderFailed {
            // Image render failed — fall back to a text share so the path is never a dead end.
            ShareLink(item: shareText) {
                HStack(spacing: 9) {
                    Image(systemName: "square.and.arrow.up").font(.system(size: 22, weight: .bold))
                    Text("Share my gist").font(BrandFont.hanken(18, .bold)).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .frame(height: Theme.controlLg)
                .foregroundStyle(Theme.onPrimary)
                .background(Theme.primary, in: RoundedRectangle(cornerRadius: Theme.Radius.pill, style: .continuous))
            }
            .accessibilityLabel("Share my gist")
        } else {
            // Pre-render placeholder keeps the CTA footprint stable.
            GVButton(
                "Share to story",
                variant: .primary,
                size: .lg,
                full: true,
                icon: "square.and.arrow.up",
                loading: true
            ) {}
        }
    }

    // MARK: Actions

    @MainActor
    private func saveImage() {
        guard let renderedImage else { return }
        UIImageWriteToSavedPhotosAlbum(renderedImage, nil, nil, nil)
    }

    private func copyLink() {
        UIPasteboard.general.string = shareURL.absoluteString
        copied = true
    }

    @MainActor
    private func render() {
        let renderer = ImageRenderer(content: GistShareCard(verdict: verdict, text: text, prompt: prompt))
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            renderedImage = uiImage
            rendered = Image(uiImage: uiImage)
            renderFailed = false
        } else {
            renderFailed = true   // never leave the user on an infinite spinner
        }
    }
}
