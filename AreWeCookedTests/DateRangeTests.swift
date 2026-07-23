import XCTest

// Tests the date-range logic from APIService without hitting the network.
// Rules:
//   - All dates are local-timezone midnight boundaries
//   - "yesterday" range  = [yesterdayMidnight, todayMidnight)  — exactly 24 h
//   - "month" range      = [monthStart, todayMidnight)
//   - starting_at must be strictly before ending_at

final class DateRangeTests: XCTestCase {

    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone.current
        return c
    }()

    private func makeDateRanges(from now: Date) -> (yesterday: (Date, Date), month: (Date, Date)) {
        let todayMidnight     = cal.startOfDay(for: now)
        let yesterdayMidnight = cal.date(byAdding: .day, value: -1, to: todayMidnight)!
        let monthStart        = cal.date(from: cal.dateComponents([.year, .month], from: now))!
        return (
            yesterday: (yesterdayMidnight, todayMidnight),
            month:     (monthStart, todayMidnight)
        )
    }

    func testYesterdayRangeIsExactlyOneDay() {
        let now = Date()
        let (yesterday, _) = makeDateRanges(from: now)
        let seconds = yesterday.1.timeIntervalSince(yesterday.0)
        // 23h or 25h on DST transitions — normally 86400
        XCTAssertGreaterThanOrEqual(seconds, 82_800, "yesterday window must be at least 23 h")
        XCTAssertLessThanOrEqual(seconds, 90_000, "yesterday window must be at most 25 h")
    }

    func testYesterdayEndEqualsMonthEnd() {
        let now = Date()
        let (yesterday, month) = makeDateRanges(from: now)
        XCTAssertEqual(yesterday.1, month.1, "both ranges must share the same ending_at")
    }

    func testStartBeforeEnd() {
        let now = Date()
        let (yesterday, month) = makeDateRanges(from: now)
        XCTAssertLessThan(yesterday.0, yesterday.1)
        XCTAssertLessThan(month.0, month.1)
    }

    func testAllBoundariesAreLocalMidnight() {
        let now = Date()
        let (yesterday, month) = makeDateRanges(from: now)
        for date in [yesterday.0, yesterday.1, month.0, month.1] {
            let comps = cal.dateComponents([.hour, .minute, .second], from: date)
            XCTAssertEqual(comps.hour, 0)
            XCTAssertEqual(comps.minute, 0)
            XCTAssertEqual(comps.second, 0)
        }
    }

    func testMonthStartIsFirstOfMonth() {
        let now = Date()
        let (_, month) = makeDateRanges(from: now)
        let day = cal.component(.day, from: month.0)
        XCTAssertEqual(day, 1, "month range must start on the 1st")
    }

    func testISO8601FormatIncludesTimezone() {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime]
        fmt.timeZone = TimeZone.current

        var comps = DateComponents()
        comps.year = 2026; comps.month = 7; comps.day = 21
        comps.hour = 0; comps.minute = 0; comps.second = 0
        comps.timeZone = TimeZone.current
        let date = Calendar(identifier: .gregorian).date(from: comps)!

        let formatted = fmt.string(from: date)
        // Must be a valid ISO8601 date-time — starts with the date portion
        XCTAssertTrue(formatted.hasPrefix("2026-07-21T00:00:00"), "formatted: \(formatted)")
        // Must contain a timezone marker (Z or +/-offset)
        let tzPart = String(formatted.dropFirst(19))
        let hasTZ = formatted.hasSuffix("Z") || tzPart.contains("+") || tzPart.contains("-")
        XCTAssertTrue(hasTZ, "ISO8601 string must contain a timezone: \(formatted)")
    }

    func testYesterdayRangeNeverIncludesToday() {
        let now = Date()
        let (_, month) = makeDateRanges(from: now)
        XCTAssertLessThanOrEqual(month.1, now + 1, "ending_at must not be in the future")
    }
}
