import XCTest
@testable import WhoAmI

final class AgeGateViewModelTests: XCTestCase {

    func testExactly18IsEligible() {
        let now = Date()
        let dob = Calendar.current.date(byAdding: .year, value: -18, to: now)!
        XCTAssertTrue(AgeGateViewModel.isEighteenPlus(dob: dob, asOf: now))
    }

    func testJustUnder18IsNotEligible() {
        let now = Date()
        // 18th birthday is tomorrow → not yet eligible.
        let dob = Calendar.current.date(byAdding: .day, value: 1,
                  to: Calendar.current.date(byAdding: .year, value: -18, to: now)!)!
        XCTAssertFalse(AgeGateViewModel.isEighteenPlus(dob: dob, asOf: now))
    }

    func testClearlyOver18IsEligible() {
        let now = Date()
        let dob = Calendar.current.date(byAdding: .year, value: -30, to: now)!
        XCTAssertTrue(AgeGateViewModel.isEighteenPlus(dob: dob, asOf: now))
    }
}
