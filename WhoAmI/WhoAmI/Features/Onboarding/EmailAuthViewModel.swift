import Foundation
import Observation

/// Email + password auth for the testable build. (Phone SMS OTP remains the production
/// plan per PRODUCT.md §6.1; email avoids a paid SMS provider for development.)
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
}
