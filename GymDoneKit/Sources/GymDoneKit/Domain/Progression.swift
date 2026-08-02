import Foundation

// Port of `get-gym-done-web/src/domain/progression.ts`.
//
// This is the subtlest function in the app — it decides when to tell someone "time to
// add weight" — so the rules are reproduced literally rather than paraphrased.

public struct WeightSuggestion: Equatable, Sendable {
    /// The weight (kg) hit across the recent qualifying sessions.
    public let currentWeightKg: Double
    /// Lowest reps hit in the qualifying bucket.
    public let reps: Int
    /// Suggested next weight (kg) = currentWeightKg + increment.
    public let suggestedWeightKg: Double

    public init(currentWeightKg: Double, reps: Int, suggestedWeightKg: Double) {
        self.currentWeightKg = currentWeightKg
        self.reps = reps
        self.suggestedWeightKg = suggestedWeightKg
    }
}

/// Progressive-overload advice for one exercise.
///
/// `history` is every completed `SetLog` for a single exercise, from completed sessions
/// only (never the in-progress one).
///
/// The rules, all load-bearing:
///   1. Group the logs by session, order groups by their latest `completedAt` DESC, and
///      take the `sessions` most recent. Fewer than that many groups -> no advice.
///   2. Bucket by set NUMBER across those sessions. A set position missing from any one
///      of the sessions is skipped entirely — you can't compare set 4 if last time there
///      were only three sets.
///   3. A bucket qualifies only if every weight in it is equal within 1e-3 (float noise
///      from kg<->lb conversion, not a real difference) AND every rep count is at least
///      `max(repsHigh, 1)` — i.e. the top of the prescribed range was cleared every time.
///   4. Among qualifying buckets take the HEAVIEST weight; report the MINIMUM reps seen
///      in that bucket, so the message quotes the worst-case performance, not the best.
public func weightIncreaseSuggestion(
    history: [SetLog],
    repsHigh: Int,
    incrementKg: Double,
    sessions: Int = 2
) -> WeightSuggestion? {
    if history.isEmpty { return nil }

    var groups: [String: [SetLog]] = [:]
    for log in history {
        groups[log.sessionId, default: []].append(log)
    }

    let ordered = groups.values
        .map { logs -> (logs: [SetLog], maxAt: Int) in
            (logs, logs.map(\.completedAt).max() ?? 0)
        }
        .sorted { $0.maxAt > $1.maxAt }

    if ordered.count < sessions { return nil }

    let recent = Array(ordered.prefix(sessions))
    let threshold = max(repsHigh, 1)

    var setNumbers = Set<Int>()
    for group in recent {
        for log in group.logs { setNumbers.insert(log.setNumber) }
    }

    var bestWeight = -Double.infinity
    var bestReps = 0

    for setNumber in setNumbers {
        let perSession = recent.map { group in
            group.logs.filter { $0.setNumber == setNumber }
        }
        // Rule 2: absent from any session -> ignore this set position entirely.
        if perSession.contains(where: { $0.isEmpty }) { continue }

        let all = perSession.flatMap { $0 }
        guard let first = all.first else { continue }
        let w0 = first.weightKg

        // Rule 3.
        if !all.allSatisfy({ abs($0.weightKg - w0) < 1e-3 }) { continue }
        if !all.allSatisfy({ $0.reps >= threshold }) { continue }

        // Rule 4.
        if w0 > bestWeight {
            bestWeight = w0
            bestReps = all.map(\.reps).min() ?? 0
        }
    }

    if bestWeight == -Double.infinity { return nil }
    return WeightSuggestion(
        currentWeightKg: bestWeight,
        reps: bestReps,
        suggestedWeightKg: bestWeight + incrementKg
    )
}
