import XCTest
@testable import CopilotCreditsMenuBar

final class FormatTests: XCTestCase {
    func testCompactIsWholeNumberNoSeparators() {
        XCTAssertEqual(Format.compact(278.04), "278")
        XCTAssertEqual(Format.compact(7500), "7500")
        XCTAssertEqual(Format.compact(144.26), "144")
        XCTAssertEqual(Format.compact(0.4), "0")
        XCTAssertEqual(Format.compact(0.6), "1")
        XCTAssertEqual(Format.compact(1_179_000), "1179000")   // no comma
    }

    func testPercentValueAdaptivePrecision() {
        XCTAssertEqual(Format.percentValue(0), "0%")
        XCTAssertEqual(Format.percentValue(0.0236), "0.02%")
        XCTAssertEqual(Format.percentValue(3.71), "3.7%")
        XCTAssertEqual(Format.percentValue(95), "95%")
    }
}
