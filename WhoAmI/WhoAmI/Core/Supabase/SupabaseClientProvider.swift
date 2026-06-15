import Foundation
import Supabase

/// The single shared SupabaseClient. The only place the SDK is instantiated; Services
/// take it by injection so they remain testable.
enum SupabaseClientProvider {
    static let shared = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.supabaseAnonKey
    )
}
