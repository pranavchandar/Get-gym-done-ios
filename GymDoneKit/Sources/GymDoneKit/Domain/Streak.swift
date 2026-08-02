import Foundation

// Port of `get-gym-done-web/src/domain/streak.ts`.
//
// Streaks are counted in CALENDAR DAYS, not sessions, and they bridge scheduled rest
// gaps — training Mon/Wed/Fri on a split with a 1-day rest gap is an unbroken 5-day
// streak, not three separate 1-day ones. That is why the streak adds `gap`, not 1.

/// Distinct local epoch-days on which a session was completed, most recent first.
private func completedEpochDaysDesc(_ sessions: [Session], calendar: Calendar) -> [Int] {
    var set = Set<Int>()
    for session in sessions {
        if let completedAt = session.completedAt {
            set.insert(epochDayLocal(completedAt, calendar: calendar))
        }
    }
    return set.sorted(by: >)
}

/// Current streak in calendar days, bridging scheduled rest gaps up to `maxRestGap`.
///
/// Returns 0 for no history, and 0 if the streak is dead — which is when more than
/// `maxRestGap + 1` days have passed since the most recent completed session.
public func currentStreakDays(
    sessions: [Session],
    maxRestGap: Int,
    now: Int = nowMillis(),
    calendar: Calendar = .current
) -> Int {
    let days = completedEpochDaysDesc(sessions, calendar: calendar)
    guard let mostRecent = days.first else { return 0 }

    let today = todayEpochDay(now: now, calendar: calendar)
    if today - mostRecent > maxRestGap + 1 { return 0 }

    var streak = 1
    for i in 1..<max(days.count, 1) {
        let gap = days[i - 1] - days[i]
        if gap >= 1 && gap <= maxRestGap + 1 {
            streak += gap
        } else {
            break
        }
    }
    return streak
}

/// Longest streak ever recorded. Unlike the current streak this never expires, so it is
/// walked ascending over the whole history with the same bridging rule.
public func longestStreakDays(
    sessions: [Session],
    maxRestGap: Int,
    calendar: Calendar = .current
) -> Int {
    let days = completedEpochDaysDesc(sessions, calendar: calendar).sorted()
    if days.isEmpty { return 0 }

    var best = 1
    var run = 1
    for i in 1..<max(days.count, 1) {
        let gap = days[i] - days[i - 1]
        if gap >= 1 && gap <= maxRestGap + 1 {
            run += gap
        } else {
            run = 1
        }
        if run > best { best = run }
    }
    return best
}
