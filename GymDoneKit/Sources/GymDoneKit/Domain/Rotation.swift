import Foundation

// Port of `get-gym-done-web/src/domain/rotation.ts`.
//
// The app never asks the user "what are you training today" — it derives it from where
// they left off in the split, skipping scheduled rest days.

/// Raw next day number in sequence, ignoring rest days.
public func nextDayNumber(lastCompletedDayNumber: Int?, count: Int) -> Int {
    if count <= 0 { return 1 }
    guard let last = lastCompletedDayNumber else { return 1 }
    return (last % count) + 1
}

private func lowestTrainable(_ trainable: [WorkoutDay]) -> WorkoutDay {
    trainable.reduce(trainable[0]) { $1.dayNumber < $0.dayNumber ? $1 : $0 }
}

/// The next trainable (non-rest) day given the last completed day number.
///
/// Walks forward from the last completed day, wrapping at the highest day number, and
/// returns the first non-rest day it meets. Falls back to the lowest-numbered trainable
/// day — which is also the answer for a brand-new user with no history.
public func nextWorkoutDay(
    days: [WorkoutDay],
    lastCompletedDayNumber: Int?
) -> WorkoutDay? {
    let trainable = days.filter { !$0.isRestDay }
    if trainable.isEmpty { return nil }

    guard let maxNumber = days.map(\.dayNumber).max() else { return nil }
    guard let last = lastCompletedDayNumber else { return lowestTrainable(trainable) }

    var n = last
    // Bounded walk: at most one full lap, so an all-rest tail can't spin forever.
    for _ in 0..<maxNumber {
        n = (n % maxNumber) + 1
        if let day = days.first(where: { $0.dayNumber == n }), !day.isRestDay {
            return day
        }
    }
    return lowestTrainable(trainable)
}

/// Longest CYCLIC run of rest days in the split.
///
/// This is what lets a streak survive scheduled time off: a user on a split with two
/// consecutive rest days should not lose their streak for not training on those days.
/// The run is cyclic — the gap between the last day of one week and the first of the
/// next counts — so the flag list is doubled to let a run wrap around.
///
/// Returns 0 when there are no rest days, and n when every day is a rest day.
public func maxConsecutiveRestDays(_ days: [WorkoutDay]) -> Int {
    let sorted = days.sorted { $0.dayNumber < $1.dayNumber }
    let flags = sorted.map(\.isRestDay)
    let n = flags.count
    if n == 0 { return 0 }
    if flags.allSatisfy({ $0 }) { return n }

    var maxRun = 0
    var run = 0
    for flag in flags + flags {
        if flag {
            run += 1
            if run > maxRun { maxRun = run }
        } else {
            run = 0
        }
    }
    return min(maxRun, n)
}
