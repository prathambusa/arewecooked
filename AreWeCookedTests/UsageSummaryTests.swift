import XCTest
@testable import AnthropicUsage

final class UsageSummaryTests: XCTestCase {

    // MARK: - USD conversion

    func testTodaySpendUSD() {
        let s = UsageSummary(todaySpendCents: 150, monthSpendCents: 0,
                             todayInputTokens: 0, todayOutputTokens: 0,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.todaySpendUSD, 1.50, accuracy: 0.0001)
    }

    func testMonthSpendUSD() {
        let s = UsageSummary(todaySpendCents: 0, monthSpendCents: 5000,
                             todayInputTokens: 0, todayOutputTokens: 0,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.monthSpendUSD, 50.00, accuracy: 0.0001)
    }

    func testZeroSpend() {
        let s = UsageSummary(todaySpendCents: 0, monthSpendCents: 0,
                             todayInputTokens: 0, todayOutputTokens: 0,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.todaySpendUSD, 0)
        XCTAssertEqual(s.monthSpendUSD, 0)
    }

    func testFractionalCents() {
        // API returns cents as a decimal string — e.g. 123.45 cents = $1.23
        let s = UsageSummary(todaySpendCents: 123.45, monthSpendCents: 0,
                             todayInputTokens: 0, todayOutputTokens: 0,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.todaySpendUSD, 1.2345, accuracy: 0.0001)
    }

    // MARK: - Token totals

    func testTotalTokens() {
        let s = UsageSummary(todaySpendCents: 0, monthSpendCents: 0,
                             todayInputTokens: 10_000, todayOutputTokens: 3_500,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.totalTokens, 13_500)
    }

    func testZeroTokens() {
        let s = UsageSummary(todaySpendCents: 0, monthSpendCents: 0,
                             todayInputTokens: 0, todayOutputTokens: 0,
                             lastUpdated: Date(), hasError: false, errorMessage: nil)
        XCTAssertEqual(s.totalTokens, 0)
    }

    // MARK: - Codable round-trip

    func testEncodeDecode() throws {
        let original = UsageSummary(todaySpendCents: 99.99, monthSpendCents: 1234.56,
                                    todayInputTokens: 50_000, todayOutputTokens: 12_000,
                                    lastUpdated: Date(timeIntervalSince1970: 1_000_000),
                                    hasError: false, errorMessage: nil)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UsageSummary.self, from: data)

        XCTAssertEqual(decoded.todaySpendCents, original.todaySpendCents, accuracy: 0.001)
        XCTAssertEqual(decoded.monthSpendCents, original.monthSpendCents, accuracy: 0.001)
        XCTAssertEqual(decoded.todayInputTokens, original.todayInputTokens)
        XCTAssertEqual(decoded.todayOutputTokens, original.todayOutputTokens)
        XCTAssertEqual(decoded.hasError, original.hasError)
    }

    func testEncodeDecodeWithError() throws {
        let original = UsageSummary(todaySpendCents: 0, monthSpendCents: 0,
                                    todayInputTokens: 0, todayOutputTokens: 0,
                                    lastUpdated: Date(), hasError: true,
                                    errorMessage: "HTTP 401: Unauthorized")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(UsageSummary.self, from: data)

        XCTAssertTrue(decoded.hasError)
        XCTAssertEqual(decoded.errorMessage, "HTTP 401: Unauthorized")
    }

    // MARK: - noKey static

    func testNoKeyHasError() {
        XCTAssertTrue(UsageSummary.noKey.hasError)
        XCTAssertEqual(UsageSummary.noKey.errorMessage, "Add API key in app")
        XCTAssertEqual(UsageSummary.noKey.todaySpendCents, 0)
        XCTAssertEqual(UsageSummary.noKey.totalTokens, 0)
    }
}
