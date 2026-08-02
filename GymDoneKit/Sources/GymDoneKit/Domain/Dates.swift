import Foundation

// Port of `get-gym-done-web/src/domain/dates.ts`.
//
// The whole app indexes days by "epoch day": the number of days since 1970-01-01 for
// the LOCAL calendar date. The web computes it as
//     Math.floor(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()) / 86400000)
// i.e. it reads the local Y/M/D, reinterprets those numbers as a UTC midnight, and
// divides. That deliberately makes the index timezone-independent for a given wall
// date, which is what the calendar, streak and heatmap all rely on.

/// Days since the Unix epoch for the LOCAL calendar date of `timestampMillis`.
public func epochDayLocal(
    _ timestampMillis: Int,
    calendar: Calendar = .current
) -> Int {
    let date = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    guard let year = parts.year, let month = parts.month, let day = parts.day else { return 0 }

    // Reinterpret the local Y/M/D as UTC midnight, matching Date.UTC(...) in JS.
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    guard let utcMidnight = utc.date(from: components) else { return 0 }

    return Int(floor(utcMidnight.timeIntervalSince1970 / 86_400.0))
}

/// Convenience for "today", with an injectable clock so tests are deterministic.
public func todayEpochDay(
    now: Int = nowMillis(),
    calendar: Calendar = .current
) -> Int {
    epochDayLocal(now, calendar: calendar)
}

/// Start-of-LOCAL-day millis for an epoch-day index — the inverse of `epochDayLocal`.
public func epochDayToMillis(
    _ epochDay: Int,
    calendar: Calendar = .current
) -> Int {
    // Read the day index back as a UTC date, then rebuild it as a local midnight.
    var utc = Calendar(identifier: .gregorian)
    utc.timeZone = TimeZone(secondsFromGMT: 0)!
    let asUTC = Date(timeIntervalSince1970: Double(epochDay) * 86_400.0)
    let parts = utc.dateComponents([.year, .month, .day], from: asUTC)

    var components = DateComponents()
    components.year = parts.year
    components.month = parts.month
    components.day = parts.day
    guard let localMidnight = calendar.date(from: components) else { return 0 }
    return Int(localMidnight.timeIntervalSince1970 * 1000.0)
}

/// Current wall-clock time in epoch milliseconds. Every "now"-dependent function takes
/// this as a default parameter so the screenshot harness can freeze the clock.
public func nowMillis() -> Int {
    Int(Date().timeIntervalSince1970 * 1000.0)
}

// MARK: - Names
//
// Hard-coded rather than locale-derived, matching the web app exactly. The UI renders
// these uppercased at the call site.

public let weekdayShort = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]

public let weekdayFull = [
    "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY",
]

public let monthNames = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

/// Local weekday index (0 = Sunday) — the index into `weekdayFull`/`weekdayShort`.
public func weekdayIndex(_ timestampMillis: Int, calendar: Calendar = .current) -> Int {
    let date = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
    // Calendar.component(.weekday:) is 1-based with Sunday == 1.
    return calendar.component(.weekday, from: date) - 1
}

/// "Aug 14" — the three-letter month plus the day of month.
public func formatDateShort(_ timestampMillis: Int, calendar: Calendar = .current) -> String {
    let date = Date(timeIntervalSince1970: Double(timestampMillis) / 1000.0)
    let parts = calendar.dateComponents([.month, .day], from: date)
    guard let month = parts.month, let day = parts.day,
          month >= 1, month <= 12 else { return "" }
    return "\(monthNames[month - 1].prefix(3)) \(day)"
}
