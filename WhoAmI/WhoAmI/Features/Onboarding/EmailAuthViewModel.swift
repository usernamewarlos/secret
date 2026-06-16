import AuthenticationServices
import CryptoKit
import Foundation
import Observation

/// Email + password auth for the testable build (Phone SMS OTP remains the production plan
/// per PRODUCT.md §6.1; email avoids a paid SMS provider for development), plus Sign in with
/// Apple and Continue with Google.
@MainActor
@Observable
final class EmailAuthViewModel {
    enum Mode { case signUp, signIn }

    var mode: Mode = .signUp
    var email = ""
    var password = ""
    var error: String?
    var info: String?
    var busy = false

    /// Raw (un-hashed) nonce for the in-flight Apple request. We send the SHA256 of it in the
    /// `ASAuthorizationAppleIDRequest`, then hand the *raw* value to Supabase, which hashes it
    /// again and compares against the identity token's `nonce` claim.
    private var currentNonce: String?

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    func submit() async {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.contains("@"), password.count >= 6 else {
            error = "Enter a valid email and a password of at least 6 characters."
            return
        }
        busy = true
        error = nil
        info = nil
        do {
            switch mode {
            case .signUp:
                try await auth.signUp(email: trimmed, password: password)
                // If the project requires email confirmation, there's no session yet.
                info = "Account created. If it needs email confirmation, tap the link we emailed, then switch to Sign in."
            case .signIn:
                try await auth.signIn(email: trimmed, password: password)
            }
        } catch {
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
        busy = false
    }

    // MARK: - Sign in with Apple

    /// Configure the `SignInWithAppleButton` request: a fresh raw nonce is generated and its
    /// SHA256 hash is attached so the returned identity token carries a matching `nonce` claim.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the `SignInWithAppleButton` completion: pull the identity token and hand it,
    /// with the *raw* nonce, to Supabase.
    func handleAppleCompletion(_ result: Result<ASAuthorization, Error>) async {
        error = nil
        info = nil
        switch result {
        case .failure(let err):
            // User-cancelled is not an error worth surfacing.
            if (err as? ASAuthorizationError)?.code == .canceled { return }
            error = err.localizedDescription
        case .success(let authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let tokenData = credential.identityToken,
                let idToken = String(data: tokenData, encoding: .utf8)
            else {
                error = "Apple sign-in did not return an identity token."
                return
            }
            guard let nonce = currentNonce else {
                error = "Invalid state: no login request was in progress."
                return
            }
            busy = true
            defer { busy = false }
            do {
                try await auth.signInWithApple(idToken: idToken, nonce: nonce)
            } catch {
                self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
            }
            currentNonce = nil
        }
    }

    // MARK: - Continue with Google

    func signInWithGoogle() async {
        error = nil
        info = nil
        busy = true
        defer { busy = false }
        do {
            try await auth.signInWithGoogle()
        } catch {
            // The system web-auth sheet throws on user cancel; don't surface that as an error.
            if (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin { return }
            self.error = (error as? AppError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Nonce helpers

    /// Cryptographically-random nonce string (Apple's recommended generator).
    private static func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset: [Character] =
            Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var randoms = [UInt8](repeating: 0, count: 16)
            let status = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if status != errSecSuccess {
                fatalError("Unable to generate nonce. SecRandomCopyBytes failed with \(status)")
            }
            for random in randoms where remaining > 0 {
                if random < charset.count {
                    result.append(charset[Int(random)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
