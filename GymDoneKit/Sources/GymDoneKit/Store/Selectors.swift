import Foundation

// Free functions over `StoreData` — a direct port of `store/selectors.ts`. Identical
// signatures (adapted to Swift's positional-argument style): `func activeSplit(_ s:
// StoreData) -> Split?` etc. See docs/ARCHITECTURE.md §5.
//
// `epochDayLocal(_:)` and `nextWorkoutDay(days:lastCompletedDayNumber:)` come from
// Domain/Dates.swift and Domain/Rotation.swift, so there is exactly one implementation
// of each rule in the package.

public func activeSplit(_ s: StoreData) -> Split? {
    guard let id = s.prefs.activeSplitId else { return nil }
    return s.splits[id]
}

public func daysOf(_ s: StoreData, _ splitId: String?) -> [WorkoutDay] {
    guard let splitId else { return [] }
    return s.workoutDays.values
        .filter { $0.splitId == splitId }
        .sorted { $0.dayNumber < $1.dayNumber }
}

public func activeDays(_ s: StoreData) -> [WorkoutDay] {
    daysOf(s, s.prefs.activeSplitId)
}

public func exercise(_ s: StoreData, _ id: String) -> Exercise? {
    s.exercises[id]
}

public func dayExercisesOf(_ s: StoreData, _ dayId: String) -> [DayExercise] {
    s.dayExercises.values
        .filter { $0.workoutDayId == dayId }
        .sorted { $0.orderIndex < $1.orderIndex }
}

public func sessionLogs(_ s: StoreData, _ sessionId: String) -> [SetLog] {
    s.setLogs.values.filter { $0.sessionId == sessionId }
}

public func allCompletedSessions(_ s: StoreData) -> [Session] {
    s.sessions.values
        .filter { $0.completedAt != nil }
        .sorted { ($0.completedAt ?? 0) < ($1.completedAt ?? 0) }
}

/// Last completed session (with a day in the active split) day number → drives rotation.
public func lastCompletedDayNumber(_ s: StoreData) -> Int? {
    let days = activeDays(s)
    let dayIds = Set(days.map { $0.id })
    var best: Session?
    for se in s.sessions.values {
        guard se.completedAt != nil, let workoutDayId = se.workoutDayId else { continue }
        guard dayIds.contains(workoutDayId) else { continue }
        if best == nil || (se.completedAt ?? 0) > (best?.completedAt ?? 0) {
            best = se
        }
    }
    guard let best, let workoutDayId = best.workoutDayId else { return nil }
    return s.workoutDays[workoutDayId]?.dayNumber
}

public func nextDay(_ s: StoreData) -> WorkoutDay? {
    nextWorkoutDay(days: activeDays(s), lastCompletedDayNumber: lastCompletedDayNumber(s))
}

/// Completed set-log history of one exercise (completed sessions only).
public func completedHistoryForExercise(_ s: StoreData, _ exerciseId: String) -> [SetLog] {
    let completedIds = Set(s.sessions.values.filter { $0.completedAt != nil }.map { $0.id })
    return s.setLogs.values.filter { $0.exerciseId == exerciseId && completedIds.contains($0.sessionId) }
}

/// Logs from the most recent completed session that recorded this exercise.
public func lastCompletedLogsForExercise(_ s: StoreData, _ exerciseId: String) -> [SetLog] {
    var bySession: [String: [SetLog]] = [:]
    var completed: [String: Int] = [:]
    for se in s.sessions.values {
        if let completedAt = se.completedAt {
            completed[se.id] = completedAt
        }
    }
    for l in s.setLogs.values {
        guard l.exerciseId == exerciseId, completed[l.sessionId] != nil else { continue }
        bySession[l.sessionId, default: []].append(l)
    }
    var bestId: String?
    var bestAt = Int.min
    for id in bySession.keys {
        let at = completed[id] ?? 0
        if at > bestAt {
            bestAt = at
            bestId = id
        }
    }
    guard let bestId else { return [] }
    return (bySession[bestId] ?? []).sorted { $0.setNumber < $1.setNumber }
}

public func customSplits(_ s: StoreData) -> [Split] {
    s.splits.values.filter { $0.isCustom }
}

public func completedCountForDay(_ s: StoreData, _ dayId: String) -> Int {
    s.sessions.values.filter {
        $0.workoutDayId == dayId && $0.completedAt != nil && $0.notes != GymDoneConstants.restSessionNote
    }.count
}

public func bodyMetricsSorted(_ s: StoreData) -> [BodyMetric] {
    s.bodyMetrics.values.sorted { $0.recordedAt < $1.recordedAt }
}

/// epoch-day -> day number trained (completed sessions with a workoutDayId).
public func completedByEpochDay(_ s: StoreData) -> [Int: Int] {
    var map: [Int: Int] = [:]
    for se in s.sessions.values {
        guard let completedAt = se.completedAt, let workoutDayId = se.workoutDayId else { continue }
        guard let wd = s.workoutDays[workoutDayId] else { continue }
        map[epochDayLocal(completedAt)] = wd.dayNumber
    }
    return map
}

/// epoch-day -> activity type for day-less activity logs.
public func activityByEpochDay(_ s: StoreData) -> [Int: String] {
    var map: [Int: String] = [:]
    for se in s.sessions.values {
        guard let completedAt = se.completedAt, se.workoutDayId == nil else { continue }
        guard se.notes != GymDoneConstants.restSessionNote else { continue }
        map[epochDayLocal(completedAt)] = se.activityType ?? "Activity"
    }
    return map
}

/// Mirrors store.ts's `recomputeDayCount` (exported there but, as of that file, never
/// actually called — kept here for parity/completeness since it's part of the public
/// surface being ported).
public func recomputeDayCount(_ s: StoreData, _ splitId: String) -> Int {
    daysOf(s, splitId).count
}
