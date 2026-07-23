import XCTest

// Tests for the formatting helpers in DesktopWidgetView.
// Duplicated here as free functions so they're testable without a view.

private func usd(_ v: Double) -> String { String(format: "$%.2f", v) }
private func shortTok(_ n: Int) -> String {
    n >= 1_000_000 ? String(format: "%.1fM", Double(n)/1_000_000)
    : n >= 1_000 ? String(format: "%.1fK", Double(n)/1_000) : "\(n)"
}

final class FormattingTests: XCTestCase {

    // MARK: - usd()

    func testUSDZero()       { XCTAssertEqual(usd(0), "$0.00") }
    func testUSDOneCent()    { XCTAssertEqual(usd(0.01), "$0.01") }
    func testUSDOneDollar()  { XCTAssertEqual(usd(1.0), "$1.00") }
    func testUSDRounding()   { XCTAssertEqual(usd(1.2345), "$1.23") }
    func testUSDLargeValue() { XCTAssertEqual(usd(1234.56), "$1234.56") }

    // MARK: - shortTok()

    func testShortTokZero()          { XCTAssertEqual(shortTok(0), "0") }
    func testShortTokSmall()         { XCTAssertEqual(shortTok(999), "999") }
    func testShortTokThousand()      { XCTAssertEqual(shortTok(1_000), "1.0K") }
    func testShortTokTenK()          { XCTAssertEqual(shortTok(10_000), "10.0K") }
    func testShortTokJustUnderMil()  { XCTAssertEqual(shortTok(999_999), "1000.0K") }
    func testShortTokMillion()       { XCTAssertEqual(shortTok(1_000_000), "1.0M") }
    func testShortTokFiveMil()       { XCTAssertEqual(shortTok(5_500_000), "5.5M") }

    // MARK: - cost math (cents → USD display)

    func testCostRoundTrip() {
        // 123.45 cents from API → todaySpendUSD = 1.2345 → displayed as $1.23
        let cents = 123.45
        let usdValue = cents / 100.0
        XCTAssertEqual(usdValue, 1.2345, accuracy: 0.0001)
        XCTAssertEqual(usd(usdValue), "$1.23")
    }

    func testZeroCost() {
        XCTAssertEqual(usd(0.0 / 100.0), "$0.00")
    }
}
