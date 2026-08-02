import Foundation

// The persisted state tree — a direct port of `StoreData` in `store/store.ts`.
//
// Same `[String: T]` dictionaries, same JSON key names as the web's persisted blob
// (Swift's synthesized Codable for `[String: T]` encodes as a JSON *object* keyed by
// the dictionary's String keys, exactly like TS's `Record<string, T>`), so a raw
// `localStorage["get-gym-done:v1"]` dump decodes into this type unmodified. See
// docs/ARCHITECTURE.md §4.

/// The whole app's persisted state. One value, one file — see `Persistence.swift`.
public struct StoreData: Codable, Sendable, Equatable {
    public var seedVersion: Int
    public var splits: [String: Split]
    public var workoutDays: [String: WorkoutDay]
    public var dayExercises: [String: DayExercise]
    public var exercises: [String: Exercise]
    public var sessions: [String: Session]
    public var setLogs: [String: SetLog]
    public var bodyMetrics: [String: BodyMetric]
    public var prefs: UserPrefs
    public var activeSession: ActiveSessionState?
    public var confettiArmed: Bool

    /// Mirrors `initialData()` in store.ts — every dictionary empty, default prefs,
    /// no active session. `seedVersion: 0` is what tells `ensureSeeded()` this is a
    /// first run.
    public init(
        seedVersion: Int = 0,
        splits: [String: Split] = [:],
        workoutDays: [String: WorkoutDay] = [:],
        dayExercises: [String: DayExercise] = [:],
        exercises: [String: Exercise] = [:],
        sessions: [String: Session] = [:],
        setLogs: [String: SetLog] = [:],
        bodyMetrics: [String: BodyMetric] = [:],
        prefs: UserPrefs = UserPrefs(),
        activeSession: ActiveSessionState? = nil,
        confettiArmed: Bool = false
    ) {
        self.seedVersion = seedVersion
        self.splits = splits
        self.workoutDays = workoutDays
        self.dayExercises = dayExercises
        self.exercises = exercises
        self.sessions = sessions
        self.setLogs = setLogs
        self.bodyMetrics = bodyMetrics
        self.prefs = prefs
        self.activeSession = activeSession
        self.confettiArmed = confettiArmed
    }
}

/// Mirrors TypeScript's `Partial<StoreData>`, the parameter type of the one action that
/// needs it (`replaceAll`, used only by `Backup.apply`). Every field is optional; only
/// the ones you set are applied on top of a fresh `StoreData()`.
///
/// Scope note: `seedVersion` and `activeSession` are deliberately **not** patchable
/// fields here. In store.ts, `replaceAll` builds `{ ...initialData(), ...data,
/// seedVersion: SEED_VERSION, activeSession: null }` — note the two forced fields come
/// *after* the `...data` spread, so they always win regardless of what a caller passes.
/// `AppStore.replaceAll` reproduces that by always forcing them itself, so there is
/// nothing for those two fields to do in the patch type. This also sidesteps the
/// "double optional" that `activeSession`'s own nullability would otherwise force onto
/// a literal `Partial` translation (outer optional = "provided", inner = "value or
/// null") — not needed since it is always overridden anyway.
public struct StoreDataPatch: Sendable {
    public var splits: [String: Split]?
    public var workoutDays: [String: WorkoutDay]?
    public var dayExercises: [String: DayExercise]?
    public var exercises: [String: Exercise]?
    public var sessions: [String: Session]?
    public var setLogs: [String: SetLog]?
    public var bodyMetrics: [String: BodyMetric]?
    public var prefs: UserPrefs?
    public var confettiArmed: Bool?

    public init(
        splits: [String: Split]? = nil,
        workoutDays: [String: WorkoutDay]? = nil,
        dayExercises: [String: DayExercise]? = nil,
        exercises: [String: Exercise]? = nil,
        sessions: [String: Session]? = nil,
        setLogs: [String: SetLog]? = nil,
        bodyMetrics: [String: BodyMetric]? = nil,
        prefs: UserPrefs? = nil,
        confettiArmed: Bool? = nil
    ) {
        self.splits = splits
        self.workoutDays = workoutDays
        self.dayExercises = dayExercises
        self.exercises = exercises
        self.sessions = sessions
        self.setLogs = setLogs
        self.bodyMetrics = bodyMetrics
        self.prefs = prefs
        self.confettiArmed = confettiArmed
    }
}
