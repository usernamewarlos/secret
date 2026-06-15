import Foundation
import Observation

/// 18+ gate (README hard constraint #1). Neutral DOB entry, not a yes/no.
@MainActor
@Observable
final class AgeGateViewModel {
    var dob: Date = Calendar.current.date(byAdding: .year, value: -18, to: Date()) ?? Date()
    var error: String?

    func isEligible(asOf now: Date = Date()) -> Bool {
        Self.isEighteenPlus(dob: dob, asOf: now)
    }

    /// Pure, testable age check. `nonisolated` so tests can call it off the main actor.
    nonisolated static func isEighteenPlus(dob: Date, asOf now: Date = Date()) -> Bool {
        guard let eighteenth = Calendar.current.date(byAdding: .year, value: 18, to: dob) else {
            return false
        }
        return eighteenth <= now
    }
}
