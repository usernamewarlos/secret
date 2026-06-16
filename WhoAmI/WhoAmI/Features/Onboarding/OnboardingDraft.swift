import Foundation

/// Carries onboarding choices made *before* sign-in (e.g. the date of birth entered at the
/// age gate) across the auth-state flip into `ProfileSetupView`.
///
/// `RootView` instantiates `OnboardingView` and `ProfileSetupView` independently — once auth
/// flips, the in-memory `OnboardingView` state is gone — so the DOB is parked in `UserDefaults`
/// rather than passed down the view tree. It is cleared once the profile is saved.
enum OnboardingDraft {
    private static let dobKey = "onboarding.pendingDOB"

    /// `yyyy-MM-dd`, UTC — the format the DB `dob` column / `profile.upsert(dob:)` expects.
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dobString(from date: Date) -> String {
        formatter.string(from: date)
    }

    /// The DOB chosen at the age gate, as a `yyyy-MM-dd` string, or nil if none was stored.
    static var pendingDOB: String? {
        get { UserDefaults.standard.string(forKey: dobKey) }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: dobKey)
            } else {
                UserDefaults.standard.removeObject(forKey: dobKey)
            }
        }
    }

    static func clear() {
        pendingDOB = nil
    }
}
