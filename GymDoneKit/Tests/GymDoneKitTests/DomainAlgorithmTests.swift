import XCTest
@testable import GymDoneKit

/// Tests for the three algorithms that decide what the app tells the user to do:
/// progressive overload, streaks, and where they are in their split.
///
/// Every case here is drawn from a rule stated in the TypeScript doc comments. These are
/// the behaviours a reader would assume are "obvious" and get subtly wrong on a report —
/// so they are pinned explicitly.
final class DomainAlgorithmTests: XCTestCase {

    // A fixed UTC calendar keeps epoch-day maths independent of the CI runner's timezone.
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(secondsFromGMT: 0)!
        return c
    }
    private func millis(day: Int, hour: Int = 12) -> Int {
        day * 86_400_000 + hour * 3_600_000
    }
    private func day(_ number: Int, rest: Bool = false) -> WorkoutDay {
        WorkoutDay(
            id: "d\(number)", splitId: "s", dayNumber: number,
            name: rest ? "Rest" : "Day \(number)", muscleGroups: [], isRestDay: rest
        )
    }
    private func log(
        session: String, exercise: String = "ex", set: Int,
        kg: Double, reps: Int, at: Int
    ) -> SetLog {
        SetLog(
            id: "\(session)-\(set)", sessionId: session, exerciseId: exercise,
            setNumber: set, weightKg: kg, reps: reps, completedAt: at
        )
    }
    private func session(_ id: String, completedDay: Int?) -> Session {
        Session(
            id: id, workoutDayId: "d1", startedAt: millis(day: completedDay ?? 0),
            completedAt: completedDay.map { millis(day: $0) }, notes: nil
        )
    }

    // MARK: - Progression

    func testSuggestionNeedsTwoSessions() {
        let history = [log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 1))]
        XCTAssertNil(
            weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5),
            "one session is not enough evidence to recommend adding weight"
        )
    }

    func testSuggestionWhenRepTargetClearedTwice() {
        let history = [
            log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 100, reps: 11, at: millis(day: 3)),
        ]
        let s = weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5)
        XCTAssertEqual(s?.currentWeightKg, 100)
        XCTAssertEqual(s?.suggestedWeightKg, 102.5)
        // Reported reps are the WORST of the qualifying bucket, not the best.
        XCTAssertEqual(s?.reps, 11)
    }

    func testNoSuggestionWhenRepTargetMissed() {
        let history = [
            log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 100, reps: 9, at: millis(day: 3)),
        ]
        XCTAssertNil(weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5))
    }

    func testWeightsWithinFloatToleranceCountAsEqual() {
        // 1e-4 apart: the kind of drift a kg->lb->kg round trip produces, not a real
        // difference in load. The rule is `abs(w - w0) < 1e-3`.
        let history = [
            log(session: "a", set: 1, kg: 100.0, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 100.0001, reps: 12, at: millis(day: 3)),
        ]
        XCTAssertNotNil(weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5))
    }

    func testWeightsBeyondToleranceDoNotQualify() {
        let history = [
            log(session: "a", set: 1, kg: 100.0, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 102.5, reps: 12, at: millis(day: 3)),
        ]
        XCTAssertNil(weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5))
    }

    func testSetPositionMissingFromOneSessionIsSkipped() {
        // Set 2 only exists in the newer session, so it cannot be compared and must be
        // ignored entirely rather than treated as a qualifying bucket.
        let history = [
            log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 100, reps: 12, at: millis(day: 3)),
            log(session: "b", set: 2, kg: 140, reps: 12, at: millis(day: 3)),
        ]
        let s = weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5)
        XCTAssertEqual(s?.currentWeightKg, 100, "set 2 should have been skipped, not chosen")
    }

    func testHeaviestQualifyingBucketWins() {
        let history = [
            log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 1, kg: 100, reps: 12, at: millis(day: 3)),
            log(session: "a", set: 2, kg: 120, reps: 12, at: millis(day: 1)),
            log(session: "b", set: 2, kg: 120, reps: 12, at: millis(day: 3)),
        ]
        let s = weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5)
        XCTAssertEqual(s?.currentWeightKg, 120)
    }

    func testOnlyTheTwoMostRecentSessionsAreConsidered() {
        // The old session is heavier but stale; only the two most recent count.
        let history = [
            log(session: "old", set: 1, kg: 200, reps: 12, at: millis(day: 1)),
            log(session: "a", set: 1, kg: 100, reps: 12, at: millis(day: 5)),
            log(session: "b", set: 1, kg: 100, reps: 12, at: millis(day: 7)),
        ]
        let s = weightIncreaseSuggestion(history: history, repsHigh: 10, incrementKg: 2.5)
        XCTAssertEqual(s?.currentWeightKg, 100)
    }

    func testEmptyHistory() {
        XCTAssertNil(weightIncreaseSuggestion(history: [], repsHigh: 10, incrementKg: 2.5))
    }

    // MARK: - Streaks

    func testStreakBridgesRestGaps() {
        // Trained on days 1, 3, 5 with a split allowing a 1-day rest gap. That is one
        // unbroken 5-day streak, not three 1-day ones — the bridging adds the gap.
        let sessions = [
            session("a", completedDay: 1),
            session("b", completedDay: 3),
            session("c", completedDay: 5),
        ]
        let streak = currentStreakDays(
            sessions: sessions, maxRestGap: 1, now: millis(day: 5), calendar: utc
        )
        XCTAssertEqual(streak, 5)
    }

    func testStreakBreaksOnTooLargeGap() {
        let sessions = [
            session("a", completedDay: 1),
            session("b", completedDay: 10),
        ]
        let streak = currentStreakDays(
            sessions: sessions, maxRestGap: 1, now: millis(day: 10), calendar: utc
        )
        XCTAssertEqual(streak, 1, "the day-1 session is too far back to be bridged")
    }

    func testStreakIsDeadWhenTooLongSinceLastSession() {
        let sessions = [session("a", completedDay: 1)]
        let streak = currentStreakDays(
            sessions: sessions, maxRestGap: 1, now: millis(day: 20), calendar: utc
        )
        XCTAssertEqual(streak, 0)
    }

    func testStreakSurvivesUpToTheGrace() {
        // today - mostRecent == maxRestGap + 1 is still alive; one more day is not.
        let sessions = [session("a", completedDay: 10)]
        XCTAssertEqual(
            currentStreakDays(sessions: sessions, maxRestGap: 1, now: millis(day: 12), calendar: utc),
            1
        )
        XCTAssertEqual(
            currentStreakDays(sessions: sessions, maxRestGap: 1, now: millis(day: 13), calendar: utc),
            0
        )
    }

    func testEmptyStreak() {
        XCTAssertEqual(currentStreakDays(sessions: [], maxRestGap: 1, now: millis(day: 1), calendar: utc), 0)
    }

    func testLongestStreakNeverExpires() {
        let sessions = [
            session("a", completedDay: 1),
            session("b", completedDay: 2),
            session("c", completedDay: 3),
            session("d", completedDay: 40), // long since abandoned
        ]
        XCTAssertEqual(longestStreakDays(sessions: sessions, maxRestGap: 0, calendar: utc), 3)
    }

    func testMultipleSessionsOnOneDayCountOnce() {
        let sessions = [
            Session(id: "a", workoutDayId: "d1", startedAt: 0, completedAt: millis(day: 5, hour: 8), notes: nil),
            Session(id: "b", workoutDayId: "d1", startedAt: 0, completedAt: millis(day: 5, hour: 18), notes: nil),
        ]
        XCTAssertEqual(
            currentStreakDays(sessions: sessions, maxRestGap: 0, now: millis(day: 5), calendar: utc),
            1
        )
    }

    // MARK: - Rotation

    func testNextWorkoutDaySkipsRestDays() {
        let days = [day(1), day(2), day(3, rest: true), day(4)]
        XCTAssertEqual(nextWorkoutDay(days: days, lastCompletedDayNumber: 2)?.dayNumber, 4)
    }

    func testNextWorkoutDayWrapsAround() {
        let days = [day(1), day(2), day(3, rest: true)]
        XCTAssertEqual(nextWorkoutDay(days: days, lastCompletedDayNumber: 2)?.dayNumber, 1)
    }

    func testNextWorkoutDayForNewUser() {
        let days = [day(1, rest: true), day(2), day(3)]
        XCTAssertEqual(
            nextWorkoutDay(days: days, lastCompletedDayNumber: nil)?.dayNumber, 2,
            "a fresh user starts at the lowest TRAINABLE day, not day 1"
        )
    }

    func testNextWorkoutDayWithNoTrainableDays() {
        let days = [day(1, rest: true), day(2, rest: true)]
        XCTAssertNil(nextWorkoutDay(days: days, lastCompletedDayNumber: 1))
    }

    func testMaxConsecutiveRestDaysWrapsCyclically() {
        // Rest on day 1 and day 4 of a 4-day cycle: those are adjacent across the wrap,
        // so the longest run is 2, not 1.
        let days = [day(1, rest: true), day(2), day(3), day(4, rest: true)]
        XCTAssertEqual(maxConsecutiveRestDays(days), 2)
    }

    func testMaxConsecutiveRestDaysEdgeCases() {
        XCTAssertEqual(maxConsecutiveRestDays([]), 0)
        XCTAssertEqual(maxConsecutiveRestDays([day(1), day(2)]), 0)
        XCTAssertEqual(
            maxConsecutiveRestDays([day(1, rest: true), day(2, rest: true)]), 2,
            "an all-rest split reports the cycle length, and must not loop forever"
        )
    }
}
