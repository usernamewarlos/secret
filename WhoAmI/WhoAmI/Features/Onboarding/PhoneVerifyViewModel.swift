import Foundation
import Observation

/// Phone SMS OTP verification (PRODUCT.md §6.1).
@MainActor
@Observable
final class PhoneVerifyViewModel {
    enum Step {
        case enterPhone
        case enterCode
    }

    var step: Step = .enterPhone
    var phone = ""
    var code = ""
    var error: String?
    var busy = false

    private let auth: AuthService

    init(auth: AuthService) {
        self.auth = auth
    }

    func sendCode() async {
        busy = true
        error = nil
        do {
            try await auth.sendOTP(phone: phone)
            step = .enterCode
        } catch {
            self.error = message(for: error)
        }
        busy = false
    }

    func verify() async {
        busy = true
        error = nil
        do {
            try await auth.verifyOTP(phone: phone, code: code)
            // Success flips auth state; SessionStore advances routing.
        } catch {
            self.error = message(for: error)
        }
        busy = false
    }

    private func message(for error: Error) -> String {
        (error as? AppError)?.errorDescription ?? error.localizedDescription
    }
}
