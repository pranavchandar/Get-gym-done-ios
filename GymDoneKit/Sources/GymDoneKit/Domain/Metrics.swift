import Foundation

// Port of `get-gym-done-web/src/domain/metrics.ts`.

/// Completed sessions only, ascending by completion time.
public func completedSessions(_ sessions: [Session]) -> [Session] {
    sessions
        .filter { $0.completedAt != nil }
        .sorted { ($0.completedAt ?? 0) < ($1.completedAt ?? 0) }
}

/// Total tonnage: the sum of weight × reps over every set.
public func totalVolumeKg(_ setLogs: [SetLog]) -> Double {
    setLogs.reduce(0.0) { $0 + $1.weightKg * Double($1.reps) }
}

/// A "training" session is a completed session that is not an auto-logged rest day.
/// Rest logs share the Session table, so this distinction drives every stat that should
/// count actual lifting.
public func isTrainingSession(_ session: Session) -> Bool {
    session.completedAt != nil && session.notes != GymDoneConstants.restSessionNote
}

/// Compact number formatting: 1.2M / 3.4k / plain integer.
public func compactNumber(_ value: Double) -> String {
    let magnitude = abs(value)
    if magnitude >= 1_000_000 { return trimTrailing(value / 1_000_000) + "M" }
    if magnitude >= 1_000 { return trimTrailing(value / 1_000) + "k" }
    return String(Int(value.rounded()))
}

private func trimTrailing(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded == rounded.rounded() { return String(Int(rounded)) }
    return String(format: "%.1f", rounded)
}

/// Heaviest top-set weight within a set of logs.
public func maxWeight(_ logs: [SetLog]) -> Double {
    logs.reduce(0.0) { max($0, $1.weightKg) }
}

/// Number of exercises in `sessionLogs` whose top weight beats every earlier session's
/// top weight for that exercise.
///
/// `priorMaxByExercise` must contain the max weight per exercise across strictly
/// earlier completed sessions. A brand-new exercise counts as a PR, but only if the
/// weight is above zero — otherwise a bodyweight set would register as a record.
public func countPRs(
    sessionLogs: [SetLog],
    priorMaxByExercise: [String: Double]
) -> Int {
    var thisMax: [String: Double] = [:]
    for log in sessionLogs {
        thisMax[log.exerciseId] = max(thisMax[log.exerciseId] ?? 0, log.weightKg)
    }
    var count = 0
    for (exerciseId, weight) in thisMax where weight > 0 {
        if let prior = priorMaxByExercise[exerciseId] {
            if weight > prior { count += 1 }
        } else {
            count += 1
        }
    }
    return count
}
