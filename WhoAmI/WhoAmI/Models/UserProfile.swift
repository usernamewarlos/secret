import Foundation

/// Mirrors `public.users`. Named UserProfile to avoid clashing with `Supabase.User`.
struct UserProfile: Codable, Identifiable, Sendable {
    let id: UUID
    var displayName: String?
    var photoURL: String?
    var bio: String?
    var dob: String?
    var ageVerified: Bool
    var verifiedPhone: Bool
    var igHandle: String?
    var createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case photoURL = "photo_url"
        case bio
        case dob
        case ageVerified = "age_verified"
        case verifiedPhone = "verified_phone"
        case igHandle = "ig_handle"
        case createdAt = "created_at"
    }
}
