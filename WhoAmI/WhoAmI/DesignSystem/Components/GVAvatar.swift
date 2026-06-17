import SwiftUI

// =============================================================================
// GVAvatar — Grapevine circular avatar.
//
// A circular profile image with an initials fallback on a deterministic,
// name-derived brand tint. The optional tangerine `ring` marks an approved /
// trusted replier (the trusted layer).
//
// Ported from design_system/components/data-display/Avatar.jsx:
//   • sizes sm/md/lg/xl → 32 / 44 / 64 / 96pt
//   • initials = first char of up to the first two words, uppercased, "?" if none
//   • deterministic tint: h = (h*31 + charCode) >>> 0 over the name, palette[h % n]
//   • image sits on surface-2; initials render white on the tint
//   • ring = a bg gap then a primary ring (CSS: 0 0 0 2.5px bg, 0 0 0 5px primary)
// =============================================================================

struct GVAvatar: View {
    enum Size {
        case sm, md, lg, xl

        /// Outer diameter in points (--avatar-sm…--avatar-xl).
        var dim: CGFloat {
            switch self {
            case .sm: return Theme.avatarSm   // 32
            case .md: return Theme.avatarMd   // 44
            case .lg: return Theme.avatarLg   // 64
            case .xl: return Theme.avatarXl   // 96
            }
        }

        /// Initials font size (fontSizes map in the source).
        var fontSize: CGFloat {
            switch self {
            case .sm: return 13
            case .md: return 17
            case .lg: return 24
            case .xl: return 36
            }
        }
    }

    private let name: String?
    private let imageURL: URL?
    private let size: Size
    private let ring: Bool

    init(name: String?, imageURL: URL? = nil, size: Size = .md, ring: Bool = false) {
        self.name = name
        self.imageURL = imageURL
        self.size = size
        self.ring = ring
    }

    // MARK: - Derived

    private var safeName: String { name ?? "" }

    /// First letter of up to the first two whitespace-separated words, uppercased.
    private var initials: String {
        let parts = safeName
            .split(separator: " ", omittingEmptySubsequences: true)
            .prefix(2)
            .compactMap { $0.first }
        let joined = String(parts).uppercased()
        return joined.isEmpty ? "?" : joined
    }

    /// Deterministic brand tint hashed from the name.
    /// Mirrors JS: `h = (h * 31 + charCode) >>> 0` (unsigned 32-bit, wrapping).
    private var tint: Color {
        let palette: [Color] = [
            Theme.Tangerine.s400,   // --tangerine-400
            Theme.Grape.s400,       // --grape-400
            Tone.social.color,      // --tone-social
            Tone.wholesome.color,   // --tone-wholesome
            Tone.playful.color      // --tone-playful
        ]
        var h: UInt32 = 0
        for scalar in safeName.unicodeScalars {
            h = h &* 31 &+ UInt32(truncatingIfNeeded: scalar.value)
        }
        return palette[Int(h % UInt32(palette.count))]
    }

    // MARK: - Body

    var body: some View {
        let dim = size.dim

        fill
            .frame(width: dim, height: dim)
            .clipShape(Circle())
            .modifier(RingModifier(active: ring, dim: dim))
            .accessibilityElement()
            .accessibilityLabel(safeName.isEmpty ? "Avatar" : safeName)
    }

    @ViewBuilder
    private var fill: some View {
        if let imageURL {
            AsyncImage(url: imageURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    // While loading / on failure, sit the initials on surface-2
                    // (the source renders an image slot on --surface-2).
                    initialsView(background: Theme.surface2)
                }
            }
        } else {
            initialsView(background: tint)
        }
    }

    private func initialsView(background: Color) -> some View {
        ZStack {
            background
            Text(initials)
                .font(BrandFont.hanken(size.fontSize, .heavy))
                .foregroundStyle(Color.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}

// =============================================================================
// Ring — the trusted-replier marker.
//
// CSS box-shadow was `0 0 0 2.5px var(--bg), 0 0 0 5px var(--primary)`:
// a 2.5px bg gap ringed by a 2.5px primary band. Rendered here as two
// concentric stroked circles drawn outside the avatar's clip so the gap reads.
// =============================================================================

private struct RingModifier: ViewModifier {
    let active: Bool
    let dim: CGFloat

    func body(content: Content) -> some View {
        if active {
            let gap: CGFloat = 2.5      // bg gap
            let band: CGFloat = 2.5     // primary band
            content
                .overlay(
                    Circle()
                        .inset(by: -(gap + band / 2))
                        .stroke(Theme.primary, lineWidth: band)
                )
                .overlay(
                    Circle()
                        .inset(by: -(gap / 2))
                        .stroke(Theme.bg, lineWidth: gap)
                )
                // Reserve room so the ring isn't clipped by tight layouts.
                .padding(gap + band)
        } else {
            content
        }
    }
}

// =============================================================================
// Preview
// =============================================================================

#Preview {
    ZStack {
        Theme.bg.ignoresSafeArea()
        VStack(spacing: Theme.Space.x8) {
            HStack(spacing: Theme.Space.x6) {
                GVAvatar(name: "Maya Okafor", size: .sm)
                GVAvatar(name: "Theo Lindgren", size: .md)
                GVAvatar(name: "Priya Anand", size: .lg)
                GVAvatar(name: "Sam", size: .xl)
            }

            HStack(spacing: Theme.Space.x8) {
                GVAvatar(name: "Rae Quartz", size: .lg, ring: true)
                GVAvatar(name: nil, size: .lg)
                GVAvatar(name: "Jordan Vale",
                         imageURL: URL(string: "https://example.com/missing.jpg"),
                         size: .lg,
                         ring: true)
            }
        }
        .padding(Theme.Space.x10)
    }
}
