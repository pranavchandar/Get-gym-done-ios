import XCTest
@testable import GymDoneKit

/// Tests for units, dates and metrics — the value-level functions whose output is read
/// directly off the screen, so an error here is visible to the user immediately.
final class DomainValueTests: XCTestCase {

    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }

    // MARK: - Units

    func testConversionsAreExactAndReversible() {
        XCTAssertEqual(kgToDisplay(100, .kg), 100)
        XCTAssertEqual(kgToDisplay(100, .lbs), 100 / 0.45359237, accuracy: 1e-9)
        // A round trip must not drift — stored weights pass through this constantly.
        let kg = 62.5
        XCTAssertEqual(displayToKg(kgToDisplay(kg, .lbs), .lbs), kg, accuracy: 1e-9)
    }

    func testStepsMatchGymPlateMaths() {
        XCTAssertEqual(displayStep(.kg), 2.5)
        XCTAssertEqual(displayStep(.lbs), 5.0)
        XCTAssertEqual(incrementKgFor(.kg), 2.5, accuracy: 1e-9)
        XCTAssertEqual(incrementKgFor(.lbs), 5.0 * 0.45359237, accuracy: 1e-9)
    }

    /// DEFECT #19 — the web shows raw conversions in lbs mode, so 20 kg displays as
    /// "44.09 lbs" and stepping yields 46.59, 49.09 … Display values now snap to 0.5.
    func testDefect19LbsDisplaySnapsToHalfPound() {
        XCTAssertEqual(displayValue(fromKg: 20, unit: .lbs), 44.0, accuracy: 1e-9)
        XCTAssertEqual(formatWeight(20, .lbs), "44")
        // …while the underlying conversion stays exact and untouched.
        XCTAssertEqual(kgToDisplay(20, .lbs), 44.09245243897997, accuracy: 1e-9)
    }

    func testKgDisplayIsUnaffectedByTheLbsFix() {
        XCTAssertEqual(formatWeight(62.5, .kg), "62.5")
        XCTAssertEqual(formatWeight(60, .kg), "60")
        XCTAssertEqual(formatWeight(0, .kg), "0")
    }

    func testFormatNumberTrimsTrailingZeros() {
        XCTAssertEqual(formatNumber(10), "10")
        XCTAssertEqual(formatNumber(10.5), "10.5")
        XCTAssertEqual(formatNumber(10.50), "10.5")
    }

    func testParseUnitIsLenient() {
        XCTAssertEqual(parseUnit("lbs"), .lbs)
        XCTAssertEqual(parseUnit("LBS"), .lbs)
        XCTAssertEqual(parseUnit("kg"), .kg)
        XCTAssertEqual(parseUnit(nil), .kg)
        XCTAssertEqual(parseUnit("nonsense"), .kg)
    }

    // MARK: - Dates

    func testEpochDayIsStableAcrossTheDay() {
        // Every instant on one local calendar date maps to the same index — this is what
        // the calendar, streak and heatmap all key on.
        let base = 20_000 * 86_400_000
        XCTAssertEqual(epochDayLocal(base, calendar: utc), 20_000)
        XCTAssertEqual(epochDayLocal(base + 23 * 3_600_000, calendar: utc), 20_000)
        XCTAssertEqual(epochDayLocal(base + 86_400_000, calendar: utc), 20_001)
    }

    func testEpochDayRoundTrip() {
        let day = 20_123
        let millis = epochDayToMillis(day, calendar: utc)
        XCTAssertEqual(epochDayLocal(millis, calendar: utc), day)
    }

    func testFormatDateShort() {
        // 1970-01-01 + 0 days == Jan 1.
        XCTAssertEqual(formatDateShort(0, calendar: utc), "Jan 1")
        XCTAssertEqual(formatDateShort(31 * 86_400_000, calendar: utc), "Feb 1")
    }

    func testNameTablesAreComplete() {
        XCTAssertEqual(weekdayShort.count, 7)
        XCTAssertEqual(weekdayFull.count, 7)
        XCTAssertEqual(monthNames.count, 12)
        XCTAssertEqual(weekdayFull[0], "SUNDAY", "index 0 must be Sunday to match the web")
    }

    // MARK: - Metrics

    func testTotalVolume() {
        let logs = [
            SetLog(id: "1", sessionId: "s", exerciseId: "e", setNumber: 1, weightKg: 100, reps: 5, completedAt: 0),
            SetLog(id: "2", sessionId: "s", exerciseId: "e", setNumber: 2, weightKg: 50, reps: 10, completedAt: 0),
        ]
        XCTAssertEqual(totalVolumeKg(logs), 1000)
        XCTAssertEqual(totalVolumeKg([]), 0)
    }

    func testCompactNumber() {
        XCTAssertEqual(compactNumber(999), "999")
        XCTAssertEqual(compactNumber(1000), "1k")
        XCTAssertEqual(compactNumber(3400), "3.4k")
        XCTAssertEqual(compactNumber(1_200_000), "1.2M")
    }

    func testRestLogsAreNotTrainingSessions() {
        let rest = Session(
            id: "r", workoutDayId: "d", startedAt: 0, completedAt: 1,
            notes: GymDoneConstants.restSessionNote
        )
        let real = Session(id: "t", workoutDayId: "d", startedAt: 0, completedAt: 1, notes: nil)
        let open = Session(id: "o", workoutDayId: "d", startedAt: 0, completedAt: nil, notes: nil)
        XCTAssertFalse(isTrainingSession(rest))
        XCTAssertTrue(isTrainingSession(real))
        XCTAssertFalse(isTrainingSession(open), "an in-progress session is not yet training history")
    }

    func testCountPRs() {
        let logs = [
            SetLog(id: "1", sessionId: "s", exerciseId: "bench", setNumber: 1, weightKg: 105, reps: 5, completedAt: 0),
            SetLog(id: "2", sessionId: "s", exerciseId: "squat", setNumber: 1, weightKg: 100, reps: 5, completedAt: 0),
            SetLog(id: "3", sessionId: "s", exerciseId: "new", setNumber: 1, weightKg: 40, reps: 5, completedAt: 0),
        ]
        let prior: [String: Double] = ["bench": 100, "squat": 120]
        // bench beats its prior, squat does not, and a never-logged exercise counts.
        XCTAssertEqual(countPRs(sessionLogs: logs, priorMaxByExercise: prior), 2)
    }

    func testZeroWeightIsNotAPR() {
        let logs = [
            SetLog(id: "1", sessionId: "s", exerciseId: "plank", setNumber: 1, weightKg: 0, reps: 60, completedAt: 0)
        ]
        XCTAssertEqual(
            countPRs(sessionLogs: logs, priorMaxByExercise: [:]), 0,
            "a bodyweight set must not register as a personal record"
        )
    }
}
