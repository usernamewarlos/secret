import Foundation
import Supabase

/// Routing phases derived from auth + profile completeness.
enum AuthPhase: Equatable {
    case loading
    case signedOut
    case needsProfile
    case signedIn
}

/// Auth boundary. Phone (SMS OTP) is the primary verification (PRODUCT.md §6.1).
protocol AuthService: Sendable {
    var currentUserID: UUID? { get }
    func signUp(email: String, password: String) async throws
    func signIn(email: String, password: String) async throws
    func sendOTP(phone: String) async throws
    func verifyOTP(phone: String, code: String) async throws
    /// Sign in with Apple. Pass the identity token + the raw nonce used to request it
    /// (Supabase compares the hashed nonce against the token's `nonce` claim).
    func signInWithApple(idToken: String, nonce: String) async throws
    /// Sign in with Google via the system web auth flow (ASWebAuthenticationSession).
    func signInWithGoogle() async throws
    func signOut() async throws
    /// Hard-delete the current account (delete_my_account RPC; cascades all data).
    func deleteAccount() async throws
    /// Emits whenever the underlying auth state changes (sign in / out / token refresh).
    func authChanges() -> AsyncStream<Void>
}

final class LiveAuthService: AuthService {
    private let client: SupabaseClient

    init(client: SupabaseClient = SupabaseClientProvider.shared) {
        self.client = client
    }

    var currentUserID: UUID? { client.auth.currentUser?.id }

    func signUp(email: String, password: String) async throws {
        try await client.auth.signUp(email: email, password: password)
    }

    func signIn(email: String, password: String) async throws {
        try await client.auth.signIn(email: email, password: password)
    }

    func sendOTP(phone: String) async throws {
        try await client.auth.signInWithOTP(phone: phone)
    }

    func verifyOTP(phone: String, code: String) async throws {
        try await client.auth.verifyOTP(phone: phone, token: code, type: .sms)
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce)
        )
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "whoami://auth-callback")
        )
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await client.rpc("delete_my_account").execute()
    }

    func authChanges() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                for await _ in client.auth.authStateChanges {
                    continuation.yield(())
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
