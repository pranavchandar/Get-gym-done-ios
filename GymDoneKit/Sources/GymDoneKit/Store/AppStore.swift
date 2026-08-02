import Foundation
import Observation

// The observable store + actions — a direct port of `store/store.ts`'s `create<Store>()
// (persist(...))` body. See docs/ARCHITECTURE.md §5 for the Zustand → Observation
// mapping this follows:
//
//   create<Store>()(persist(...))       -> @MainActor @Observable final class AppStore
//   useStore(s => s.prefs.theme)        -> store.data.prefs.theme
//   set(s => ({ ... }))                 -> AppStore.mutate { $0.foo = ... } (private helper)
//   persist middleware                  -> Persistence, debounced 400ms, off-main-actor
//   getState() for non-hook access      -> store.data (already a value type)

/// Mirrors `uid()` in store.ts. Always a UUID (the TS original's `Math.random` fallback
/// only exists for pre-`crypto.randomUUID` environments, which has no iOS analogue).
public func uid() -> String {
    UUID().uuidString
}

// `nowMillis()` — the Swift stand-in for every bare `Date.now()` in store.ts — lives in
// Domain/Dates.swift, alongside the other clock-dependent helpers, so the screenshot
// harness has a single place to freeze time. It was briefly declared here too while the
// domain layer did not yet exist; that duplicate is removed.

// MARK: - Action parameter types
//
// TS expresses these as anonymous/inline object types (`{ exerciseId: string; sets:
// number; ... }`) or local interfaces declared next to `StoreActions`. Swift needs them
// named; they live here, next to the actions that use them.

/// One row of a day's exercise prescription. Shared shape for `RoutineDraft`'s days and
/// for `saveDayExercises`'s `rows` parameter (store.ts uses the same anonymous object
/// type in both places).
public struct DraftExerciseRow: Sendable {
    public var exerciseId: String
    public var sets: Int
    public var repsLow: Int
    public var repsHigh: Int

    public init(exerciseId: String, sets: Int, repsLow: Int, repsHigh: Int) {
        self.exerciseId = exerciseId
        self.sets = sets
        self.repsLow = repsLow
        self.repsHigh = repsHigh
    }
}

/// Mirrors the `DraftDay` interface in store.ts.
public struct DraftDay: Sendable {
    public var name: String
    public var isRestDay: Bool
    public var exercises: [DraftExerciseRow]

    public init(name: String, isRestDay: Bool, exercises: [DraftExerciseRow]) {
        self.name = name
        self.isRestDay = isRestDay
        self.exercises = exercises
    }
}

/// Mirrors the `RoutineDraft` interface in store.ts.
public struct RoutineDraft: Sendable {
    public var name: String
    public var days: [DraftDay]

    public init(name: String, days: [DraftDay]) {
        self.name = name
        self.days = days
    }
}

/// The observable store. One `data` snapshot, one action method per Zustand action.
/// Injected once at the app root (`.environment(store)` per ARCHITECTURE.md §5) rather
/// than a global singleton — unlike the web's `useStore`, there is no module-level
/// `getState()` accessor here; callers that need the current snapshot outside a view
/// read `store.data` directly (already a plain value type).
@MainActor
@Observable
public final class AppStore {

    /// The full persisted state tree. Read freely (`store.data.prefs.theme`, etc.) —
    /// Observation tracks property reads automatically. Mutate only through the action
    /// methods below, never directly, so every change is debounce-persisted exactly
    /// once (mirrors the web: the UI never calls `useStore.setState` itself, only the
    /// named actions).
    public private(set) var data: StoreData

    private let persistence: Persistence
    private var saveTask: Task<Void, Never>?
    private static let saveDebounce: Duration = .milliseconds(400)

    /// Loads the on-disk snapshot (falling back to an empty store on first run or a
    /// corrupt file — see `Persistence.load()`) and wires up debounced persistence for
    /// every subsequent mutation.
    public convenience init(persistence: Persistence = Persistence()) {
        let loaded = persistence.load() ?? StoreData()
        self.init(data: loaded, persistence: persistence)
    }

    /// Explicit-snapshot entry point. Mutations are still persisted through
    /// `persistence` exactly as with the convenience initializer — useful for tests and
    /// previews that want a known starting state without touching disk at init time.
    public init(data: StoreData, persistence: Persistence = Persistence()) {
        self.data = data
        self.persistence = persistence
    }

    /// Applies `body` to `data` and schedules a debounced persist. The one path every
    /// action funnels through — the direct analogue of calling Zustand's `set(...)`,
    /// which the `persist` middleware intercepts on every call.
    private func mutate(_ body: (inout StoreData) -> Void) {
        body(&data)
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = data
        let engine = persistence
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: AppStore.saveDebounce)
            guard !Task.isCancelled else { return }
            engine.save(snapshot)
        }
    }

    /// Forces an immediate, synchronous write and cancels any pending debounced save.
    /// Call on `scenePhase` leaving `.active` and on `willTerminate` (ARCHITECTURE.md
    /// §4.2) so a backgrounded/killed app never loses the last 400ms of changes.
    public func flush() {
        saveTask?.cancel()
        saveTask = nil
        persistence.save(data)
    }

    // MARK: - ensureSeeded

    /// First run: seed everything fresh. Otherwise, when `seedVersion` is behind the
    /// catalog's: MERGE — add new exercises, update descriptive fields of existing
    /// (catalog-sourced) exercises in place, never remove anything (custom exercises
    /// are untouched because they're never keys in `catalog.exercises`), and add new
    /// preset splits/days/day-exercises without disturbing custom splits or user edits
    /// (only fills in ids absent from the current state). Mirrors `ensureSeeded` in
    /// store.ts exactly.
    ///
    /// Non-throwing: if the bundled seed resource can't be read/decoded — which
    /// shouldn't happen; `SeedCatalogTests` and a CI checksum guard the resource itself
    /// — this no-ops rather than crashing, leaving `data` as it was.
    public func ensureSeeded() {
        guard let catalog = try? Seed.buildCatalog() else { return }

        if data.seedVersion == 0 || data.exercises.isEmpty {
            mutate { s in
                s.seedVersion = Seed.version
                s.splits = catalog.splits
                s.workoutDays = catalog.workoutDays
                s.dayExercises = catalog.dayExercises
                s.exercises = catalog.exercises
            }
            return
        }

        if data.seedVersion < Seed.version {
            mutate { s in
                // TS does `exercises[id] = { ...exercises[id], ...ex }`. Since `Exercise`
                // has no fields beyond seed.ts's, spreading the catalog value last always
                // fully overwrites — equivalent to a plain assignment here.
                var exercises = s.exercises
                for (id, ex) in catalog.exercises {
                    exercises[id] = ex
                }
                var splits = s.splits
                var workoutDays = s.workoutDays
                var dayExercises = s.dayExercises
                for (id, sp) in catalog.splits where splits[id] == nil {
                    splits[id] = sp
                }
                for (id, wd) in catalog.workoutDays where workoutDays[id] == nil {
                    workoutDays[id] = wd
                }
                for (id, de) in catalog.dayExercises where dayExercises[id] == nil {
                    dayExercises[id] = de
                }
                s.seedVersion = Seed.version
                s.exercises = exercises
                s.splits = splits
                s.workoutDays = workoutDays
                s.dayExercises = dayExercises
            }
        }
    }

    // MARK: - Prefs

    public func setTheme(_ t: ThemeChoice) {
        mutate { $0.prefs.theme = t }
    }

    public func setUnits(_ u: Units) {
        mutate { $0.prefs.units = u }
    }

    public func setAccent(_ a: String) {
        mutate { $0.prefs.accent = a }
    }

    /// Mirrors `setProfile` in store.ts. TS's parameter type is a genuine
    /// `Partial`-with-nullable-fields (`{ handle?: string | null; ... }`): a field
    /// absent leaves the existing value, present-even-as-null overwrites it. The
    /// *only* real call site (`Profile.tsx`'s `EditProfileSheet`) always supplies all
    /// three fields together, so this is simplified to three required-but-nullable
    /// parameters — behaviourally identical to every actual usage, and it avoids a
    /// `String??` (double-optional) parameter shape that would be easy to get wrong
    /// with no compiler available to check it.
    public func setProfile(handle: String?, color: String?, avatarPhoto: String?) {
        mutate { s in
            s.prefs.handle = handle
            s.prefs.color = color
            s.prefs.avatarPhoto = avatarPhoto
        }
    }

    // MARK: - Splits / onboarding

    public func activatePresetSplit(_ splitId: String) {
        mutate { s in
            s.prefs.activeSplitId = splitId
            s.prefs.onboardingComplete = true
        }
    }

    public func activateExistingSplit(_ splitId: String) {
        mutate { s in
            s.prefs.activeSplitId = splitId
            s.prefs.onboardingComplete = true
        }
    }

    @discardableResult
    public func commitCustomSplit(_ draft: RoutineDraft) -> String {
        let splitId = uid()
        var newWorkoutDays: [String: WorkoutDay] = [:]
        var newDayExercises: [String: DayExercise] = [:]

        for (i, d) in draft.days.enumerated() {
            let dayId = uid()
            newWorkoutDays[dayId] = WorkoutDay(
                id: dayId, splitId: splitId, dayNumber: i + 1, name: d.name,
                muscleGroups: [], isRestDay: d.isRestDay
            )
            for (oi, ex) in d.exercises.enumerated() {
                let id = uid()
                newDayExercises[id] = DayExercise(
                    id: id, workoutDayId: dayId, exerciseId: ex.exerciseId, orderIndex: oi,
                    prescribedSets: ex.sets, prescribedRepsLow: ex.repsLow, prescribedRepsHigh: ex.repsHigh
                )
            }
        }

        let trimmedName = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let split = Split(
            id: splitId,
            name: trimmedName.isEmpty ? "My Routine" : trimmedName,
            dayCount: draft.days.count,
            isCustom: true
        )

        mutate { s in
            s.splits[splitId] = split
            for (id, wd) in newWorkoutDays { s.workoutDays[id] = wd }
            for (id, de) in newDayExercises { s.dayExercises[id] = de }
            s.prefs.activeSplitId = splitId
            s.prefs.onboardingComplete = true
        }
        return splitId
    }

    // MARK: - Exercises

    /// Mirrors `createCustomExercise` in store.ts. TS's parameter type is
    /// `Partial<Exercise> & { name: string; primaryMuscle: string }`, but every field
    /// beyond `name`/`primaryMuscle` is applied through a `?? default` in the
    /// implementation (and `illustrationFilename` is always forced to `""`, ignoring
    /// any caller-supplied value) — so plain Swift default parameter values reproduce
    /// it exactly without needing a `Partial<Exercise>` equivalent.
    @discardableResult
    public func createCustomExercise(
        name: String,
        primaryMuscle: String,
        secondaryMuscles: [String] = [],
        formCues: [String] = [],
        equipment: String = "Other",
        defaultSets: Int = 3,
        defaultRepsLow: Int = 8,
        defaultRepsHigh: Int = 12
    ) -> String {
        let id = uid()
        let ex = Exercise(
            id: id,
            name: name,
            primaryMuscle: primaryMuscle,
            secondaryMuscles: secondaryMuscles,
            illustrationFilename: "",
            formCues: formCues,
            equipment: equipment,
            defaultSets: defaultSets,
            defaultRepsLow: defaultRepsLow,
            defaultRepsHigh: defaultRepsHigh
        )
        mutate { $0.exercises[id] = ex }
        return id
    }

    // MARK: - Day/week editing

    public func updateDayName(_ dayId: String, _ name: String) {
        mutate { s in
            guard s.workoutDays[dayId] != nil else { return }
            s.workoutDays[dayId]?.name = name
        }
    }

    /// `direction` mirrors TS's `dir: -1 | 1` (swap with the previous/next day by
    /// `dayNumber`). Swift has no clean way to spell a "-1 or 1" `Int` subset without a
    /// bespoke enum that then has to be converted right back to an offset, so this
    /// stays a plain `Int`, exactly as it's used (`idx + dir`) in store.ts.
    public func moveDay(_ splitId: String, dayNumber: Int, direction: Int) {
        mutate { s in
            let days = daysOf(s, splitId)
            guard let idx = days.firstIndex(where: { $0.dayNumber == dayNumber }) else { return }
            let other = idx + direction
            guard other >= 0, other < days.count else { return }
            let a = days[idx]
            let b = days[other]
            s.workoutDays[a.id]?.dayNumber = b.dayNumber
            s.workoutDays[b.id]?.dayNumber = a.dayNumber
        }
    }

    public func addDay(_ splitId: String, name: String) {
        mutate { s in
            let days = daysOf(s, splitId)
            let nextNum = days.isEmpty ? 1 : (days.map { $0.dayNumber }.max() ?? 0) + 1
            let dayId = uid()
            s.workoutDays[dayId] = WorkoutDay(
                id: dayId, splitId: splitId, dayNumber: nextNum, name: name,
                muscleGroups: [], isRestDay: false
            )
            if s.splits[splitId] != nil {
                s.splits[splitId]?.dayCount = days.count + 1
            }
        }
    }

    /// Returns `false` (and makes no change) when the day has logged sessions, or when
    /// the day doesn't exist. Otherwise deletes the day and its day-exercises, then
    /// renumbers the split's remaining days to stay contiguous starting at 1. Mirrors
    /// `removeDay` in store.ts exactly, including the renumbering.
    @discardableResult
    public func removeDay(_ dayId: String) -> Bool {
        guard let day = data.workoutDays[dayId] else { return false }
        let hasSessions = data.sessions.values.contains { $0.workoutDayId == dayId }
        if hasSessions { return false }

        mutate { s in
            s.workoutDays.removeValue(forKey: dayId)
            // Rebuild rather than delete-while-iterating `s.dayExercises.values`, which
            // would mutate the dictionary while a live view over it is being walked.
            s.dayExercises = s.dayExercises.filter { $0.value.workoutDayId != dayId }

            let remaining = s.workoutDays.values
                .filter { $0.splitId == day.splitId }
                .sorted { $0.dayNumber < $1.dayNumber }
            for (i, d) in remaining.enumerated() {
                s.workoutDays[d.id]?.dayNumber = i + 1
            }
            if s.splits[day.splitId] != nil {
                s.splits[day.splitId]?.dayCount = remaining.count
            }
        }
        return true
    }

    public func saveDayExercises(_ dayId: String, name: String, rows: [DraftExerciseRow]) {
        mutate { s in
            guard s.workoutDays[dayId] != nil else { return }
            s.dayExercises = s.dayExercises.filter { $0.value.workoutDayId != dayId }
            for (i, r) in rows.enumerated() {
                let id = uid()
                s.dayExercises[id] = DayExercise(
                    id: id, workoutDayId: dayId, exerciseId: r.exerciseId, orderIndex: i,
                    prescribedSets: r.sets, prescribedRepsLow: r.repsLow, prescribedRepsHigh: r.repsHigh
                )
            }
            s.workoutDays[dayId]?.name = name
        }
    }

    // MARK: - Workout session

    /// Reuses an in-progress session for `workoutDayId` if one exists (or the current
    /// active session if it's already for this day); otherwise starts a new one.
    /// Recomputes `exerciseIds` as the day's prescribed exercises plus any
    /// already-logged "extra" exercises (order-preserving de-dup of logged exercise
    /// ids, matching TS's `[...new Set(...)]`), and picks `currentIndex` as the first
    /// exercise with an unlogged set, where a set is considered still outstanding via
    /// `setCount = max(prescribedSets ?? 1, maxLoggedSetNumber)`. Mirrors
    /// `startOrResumeSession` in store.ts exactly.
    @discardableResult
    public func startOrResumeSession(_ workoutDayId: String) -> String {
        if let active = data.activeSession, active.workoutDayId == workoutDayId {
            return active.sessionId
        }

        let existingSession = data.sessions.values.first {
            $0.workoutDayId == workoutDayId && $0.completedAt == nil
        }

        var sessionsCopy = data.sessions
        let sessionId: String
        if let existingSession {
            sessionId = existingSession.id
        } else {
            sessionId = uid()
            sessionsCopy[sessionId] = Session(
                id: sessionId, workoutDayId: workoutDayId, startedAt: nowMillis(),
                completedAt: nil, notes: nil
            )
        }

        let dayExs = dayExercisesOf(data, workoutDayId)
        let baseIds = dayExs.map { $0.exerciseId }
        let baseIdSet = Set(baseIds)
        let sessionSetLogs = sessionLogs(data, sessionId)

        // Order-preserving de-dup, matching `[...new Set(arr)]`.
        var seenLogged = Set<String>()
        var loggedIds: [String] = []
        for l in sessionSetLogs where !seenLogged.contains(l.exerciseId) {
            seenLogged.insert(l.exerciseId)
            loggedIds.append(l.exerciseId)
        }
        let added = loggedIds.filter { !baseIdSet.contains($0) }
        let exerciseIds = baseIds + added

        var loggedCounts: [String: Set<Int>] = [:]
        for l in sessionSetLogs {
            loggedCounts[l.exerciseId, default: []].insert(l.setNumber)
        }

        var startIndex = 0
        for (i, exId) in exerciseIds.enumerated() {
            let de = dayExs.first { $0.exerciseId == exId }
            let logged = loggedCounts[exId]
            let maxLogged = logged.flatMap { $0.max() } ?? 0
            let setCount = max(de?.prescribedSets ?? 1, maxLogged)
            let doneCount = logged?.count ?? 0
            if doneCount < setCount {
                startIndex = i
                break
            }
        }

        let activeSession = ActiveSessionState(
            sessionId: sessionId, workoutDayId: workoutDayId, exerciseIds: exerciseIds,
            addedExerciseIds: added, currentIndex: startIndex, restEndAt: nil, restDuration: nil
        )
        mutate { s in
            s.sessions = sessionsCopy
            s.activeSession = activeSession
        }
        return sessionId
    }

    public func logSet(exerciseId: String, setNumber: Int, weightKg: Double, reps: Int) {
        guard let active = data.activeSession else { return }
        let id = uid()
        let log = SetLog(
            id: id, sessionId: active.sessionId, exerciseId: exerciseId, setNumber: setNumber,
            weightKg: weightKg, reps: reps, completedAt: nowMillis(), rir: nil
        )
        mutate { $0.setLogs[id] = log }
    }

    public func removeSet(_ setLogId: String) {
        mutate { $0.setLogs.removeValue(forKey: setLogId) }
    }

    public func undoLastSet(_ exerciseId: String) {
        guard let active = data.activeSession else { return }
        let logs = sessionLogs(data, active.sessionId)
            .filter { $0.exerciseId == exerciseId }
            .sorted { $0.completedAt < $1.completedAt }
        guard let last = logs.last else { return }
        mutate { $0.setLogs.removeValue(forKey: last.id) }
    }

    public func addExerciseToWorkout(_ exerciseId: String) {
        mutate { s in
            guard var active = s.activeSession else { return }
            if let idx = active.exerciseIds.firstIndex(of: exerciseId) {
                active.currentIndex = idx
                s.activeSession = active
                return
            }
            active.exerciseIds.append(exerciseId)
            active.addedExerciseIds.append(exerciseId)
            active.currentIndex = active.exerciseIds.count - 1
            s.activeSession = active
        }
    }

    /// Deletes the old exercise's logged sets for this session. Mirrors
    /// `replaceExercise` in store.ts (including that deletion — it's intentional
    /// there, not a defect: a replaced exercise's sets don't carry over).
    public func replaceExercise(oldExerciseId: String, newExerciseId: String) {
        guard let active = data.activeSession else { return }
        if active.exerciseIds.contains(newExerciseId) { return }
        guard let idx = active.exerciseIds.firstIndex(of: oldExerciseId) else { return }

        var exerciseIds = active.exerciseIds
        exerciseIds[idx] = newExerciseId

        let logsToDrop = Set(
            sessionLogs(data, active.sessionId)
                .filter { $0.exerciseId == oldExerciseId }
                .map { $0.id }
        )

        var addedExerciseIds = active.addedExerciseIds.filter { $0 != oldExerciseId }
        addedExerciseIds.append(newExerciseId)

        mutate { s in
            for id in logsToDrop { s.setLogs.removeValue(forKey: id) }
            var next = active
            next.exerciseIds = exerciseIds
            next.addedExerciseIds = addedExerciseIds
            s.activeSession = next
        }
    }

    public func removeExerciseFromWorkout(_ exerciseId: String) {
        guard let active = data.activeSession else { return }
        guard active.exerciseIds.count > 1 else { return }
        guard active.exerciseIds.contains(exerciseId) else { return }

        let exerciseIds = active.exerciseIds.filter { $0 != exerciseId }
        let logsToDrop = Set(
            sessionLogs(data, active.sessionId)
                .filter { $0.exerciseId == exerciseId }
                .map { $0.id }
        )
        let addedExerciseIds = active.addedExerciseIds.filter { $0 != exerciseId }
        let currentIndex = min(active.currentIndex, exerciseIds.count - 1)

        mutate { s in
            for id in logsToDrop { s.setLogs.removeValue(forKey: id) }
            var next = active
            next.exerciseIds = exerciseIds
            next.addedExerciseIds = addedExerciseIds
            next.currentIndex = currentIndex
            s.activeSession = next
        }
    }

    public func setCurrentIndex(_ i: Int) {
        mutate { s in
            guard s.activeSession != nil else { return }
            s.activeSession?.currentIndex = i
        }
    }

    public func startRestTimer(_ seconds: Int) {
        mutate { s in
            guard s.activeSession != nil else { return }
            s.activeSession?.restEndAt = nowMillis() + seconds * 1000
            s.activeSession?.restDuration = seconds
        }
    }

    // DEFECT #5 — fixed in Phase 5/6 (see docs/DEFECT-LEDGER.md #5), NOT here. The web
    // ALSO overwrites `prefs.restSeconds` on every ± nudge of the *running* timer, so
    // adjusting one set's rest silently rewrites the user's default rest duration for
    // every future set. Ported FAITHFULLY, defect included — do not "fix" this line
    // without updating the ledger disposition; the intended fix (apply ± to the running
    // timer only, add a separate "Default rest" setting) is scoped to a later phase.
    public func adjustRestTimer(_ delta: Int) {
        mutate { s in
            guard let active = s.activeSession, let restEndAt = active.restEndAt else { return }
            let curDur = active.restDuration ?? GymDoneConstants.defaultRestSeconds
            let newDur = max(GymDoneConstants.restMin, min(GymDoneConstants.restMax, curDur + delta))
            let applied = newDur - curDur
            s.prefs.restSeconds = newDur // DEFECT #5
            s.activeSession?.restEndAt = restEndAt + applied * 1000
            s.activeSession?.restDuration = newDur
        }
    }

    public func clearRestTimer() {
        mutate { s in
            guard s.activeSession != nil else { return }
            s.activeSession?.restEndAt = nil
            s.activeSession?.restDuration = nil
        }
    }

    @discardableResult
    public func finishWorkout() -> String? {
        guard let active = data.activeSession else { return nil }
        let sessionId = active.sessionId
        guard data.sessions[sessionId] != nil else {
            mutate { $0.activeSession = nil }
            return nil
        }
        mutate { s in
            s.sessions[sessionId]?.completedAt = nowMillis()
            s.activeSession = nil
        }
        return sessionId
    }

    // MARK: - Body & activity

    /// Upserts onto **today's** row (same local epoch day via `epochDayLocal`) rather
    /// than always inserting a new one. A field omitted (`nil`) from the call falls
    /// back to the existing row's value when upserting; when inserting fresh it's
    /// simply stored as `nil`. No-ops if all three fields are `nil`. Mirrors
    /// `logBodyMetric` in store.ts exactly.
    public func logBodyMetric(bodyweightKg: Double?, bodyFatPct: Double?, muscleMassKg: Double?) {
        guard bodyweightKg != nil || bodyFatPct != nil || muscleMassKg != nil else { return }
        let today = epochDayLocal(nowMillis())
        let existing = data.bodyMetrics.values.first { epochDayLocal($0.recordedAt) == today }

        if let existing {
            mutate { s in
                s.bodyMetrics[existing.id]?.bodyweightKg = bodyweightKg ?? existing.bodyweightKg
                s.bodyMetrics[existing.id]?.bodyFatPct = bodyFatPct ?? existing.bodyFatPct
                s.bodyMetrics[existing.id]?.muscleMassKg = muscleMassKg ?? existing.muscleMassKg
            }
        } else {
            let id = uid()
            let record = BodyMetric(
                id: id, recordedAt: nowMillis(),
                bodyweightKg: bodyweightKg, bodyFatPct: bodyFatPct, muscleMassKg: muscleMassKg
            )
            mutate { $0.bodyMetrics[id] = record }
        }
    }

    public func logActivity(activityType: String, durationMin: Int?, notes: String?, workoutDayId: String?) {
        let id = uid()
        let now = nowMillis()
        let session = Session(
            id: id, workoutDayId: workoutDayId, startedAt: now, completedAt: now,
            notes: notes, activityType: activityType, durationMin: durationMin
        )
        mutate { $0.sessions[id] = session }
    }

    public func autoLogRestDay(_ restDayId: String) {
        let id = uid()
        let now = nowMillis()
        let session = Session(
            id: id, workoutDayId: restDayId, startedAt: now, completedAt: now,
            notes: GymDoneConstants.restSessionNote
        )
        mutate { $0.sessions[id] = session }
    }

    // MARK: - Confetti

    public func armConfetti() {
        mutate { $0.confettiArmed = true }
    }

    public func consumeConfetti() {
        mutate { $0.confettiArmed = false }
    }

    // MARK: - Data

    /// Full wipe + re-insert. `seedVersion` is always forced to the current seed
    /// version and `activeSession` is always cleared, regardless of `patch` — mirrors
    /// `replaceAll` in store.ts exactly: `{ ...initialData(), ...data, seedVersion:
    /// SEED_VERSION, activeSession: null }`, where the two forced fields are spread
    /// *after* `...data` and so always win. The only caller is `Backup.apply`.
    public func replaceAll(_ patch: StoreDataPatch) {
        mutate { s in
            var next = StoreData()
            if let splits = patch.splits { next.splits = splits }
            if let workoutDays = patch.workoutDays { next.workoutDays = workoutDays }
            if let dayExercises = patch.dayExercises { next.dayExercises = dayExercises }
            if let exercises = patch.exercises { next.exercises = exercises }
            if let sessions = patch.sessions { next.sessions = sessions }
            if let setLogs = patch.setLogs { next.setLogs = setLogs }
            if let bodyMetrics = patch.bodyMetrics { next.bodyMetrics = bodyMetrics }
            if let prefs = patch.prefs { next.prefs = prefs }
            if let confettiArmed = patch.confettiArmed { next.confettiArmed = confettiArmed }
            next.seedVersion = Seed.version
            next.activeSession = nil
            s = next
        }
    }
}
