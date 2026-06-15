import Foundation

/// Reads build configuration injected via Info.plist (populated from the active .xcconfig).
enum AppConfig {
    static var supabaseURL: URL {
        let raw = (Bundle.main.object(forInfoDictionaryKey: "SupabaseURL") as? String) ?? ""
        let normalized = raw.hasPrefix("http") ? raw : "https://\(raw)"
        return URL(string: normalized) ?? URL(string: "https://example.supabase.co")!
    }

    static var supabaseAnonKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "SupabaseAnonKey") as? String) ?? ""
    }
}
