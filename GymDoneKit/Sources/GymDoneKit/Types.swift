import Foundation

// Domain types — a direct port of `get-gym-done-web/src/types.ts`, which itself mirrors
// the original Android Room schema.
//
// Two invariants carried over verbatim, because the whole app depends on them:
//   * all weights are stored in KILOGRAMS and converted only for display
//   * all times are epoch MILLISECONDS
//
// The JSON keys here match the web app's persisted blob and the shared `BackupFile` v2
// format exactly, so a `localStorage` dump or an Android export decodes without mapping.

// MARK: - Enumerations

public enum Units: String, Codable, Sendable, CaseIterable {
    case kg
    case lbs
}

public enum ThemeChoice: String, Codable, Sendable, CaseIterable {
    case light
    case dark
    case system
}

// MARK: - Entities

public struct Split: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var dayCount: Int
    public var isCustom: Bool

    public init(id: String, name: String, dayCount: Int, isCustom: Bool) {
        self.id = id
        self.name = name
        self.dayCount = dayCount
        self.isCustom = isCustom
    }
}

public struct WorkoutDay: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var splitId: String
    public var dayNumber: Int
    public var name: String
    public var muscleGroups: [String]
    public var isRestDay: Bool

    public init(
        id: String, splitId: String, dayNumber: Int,
        name: String, muscleGroups: [String], isRestDay: Bool
    ) {
        self.id = id
        self.splitId = splitId
        self.dayNumber = dayNumber
        self.name = name
        self.muscleGroups = muscleGroups
        self.isRestDay = isRestDay
    }
}

public struct Exercise: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var name: String
    public var primaryMuscle: String
    public var secondaryMuscles: [String]
    public var illustrationFilename: String
    public var formCues: [String]
    public var equipment: String
    public var defaultSets: Int
    public var defaultRepsLow: Int
    public var defaultRepsHigh: Int

    public init(
        id: String, name: String, primaryMuscle: String, secondaryMuscles: [String],
        illustrationFilename: String, formCues: [String], equipment: String,
        defaultSets: Int, defaultRepsLow: Int, defaultRepsHigh: Int
    ) {
        self.id = id
        self.name = name
        self.primaryMuscle = primaryMuscle
        self.secondaryMuscles = secondaryMuscles
        self.illustrationFilename = illustrationFilename
        self.formCues = formCues
        self.equipment = equipment
        self.defaultSets = defaultSets
        self.defaultRepsLow = defaultRepsLow
        self.defaultRepsHigh = defaultRepsHigh
    }
}

public struct DayExercise: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var workoutDayId: String
    public var exerciseId: String
    public var orderIndex: Int
    public var prescribedSets: Int
    public var prescribedRepsLow: Int
    public var prescribedRepsHigh: Int

    public init(
        id: String, workoutDayId: String, exerciseId: String, orderIndex: Int,
        prescribedSets: Int, prescribedRepsLow: Int, prescribedRepsHigh: Int
    ) {
        self.id = id
        self.workoutDayId = workoutDayId
        self.exerciseId = exerciseId
        self.orderIndex = orderIndex
        self.prescribedSets = prescribedSets
        self.prescribedRepsLow = prescribedRepsLow
        self.prescribedRepsHigh = prescribedRepsHigh
    }
}

public struct Session: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    /// `nil` for a logged activity that isn't tied to a scheduled day.
    public var workoutDayId: String?
    public var startedAt: Int
    /// `nil` while the session is still in progress.
    public var completedAt: Int?
    /// `REST_SESSION_NOTE` marks an auto-logged rest day.
    public var notes: String?
    public var activityType: String?
    public var durationMin: Int?

    public init(
        id: String, workoutDayId: String?, startedAt: Int, completedAt: Int?,
        notes: String?, activityType: String? = nil, durationMin: Int? = nil
    ) {
        self.id = id
        self.workoutDayId = workoutDayId
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.activityType = activityType
        self.durationMin = durationMin
    }
}

public struct SetLog: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var sessionId: String
    public var exerciseId: String
    public var setNumber: Int
    public var weightKg: Double
    public var reps: Int
    public var completedAt: Int
    public var rir: Int?

    public init(
        id: String, sessionId: String, exerciseId: String, setNumber: Int,
        weightKg: Double, reps: Int, completedAt: Int, rir: Int? = nil
    ) {
        self.id = id
        self.sessionId = sessionId
        self.exerciseId = exerciseId
        self.setNumber = setNumber
        self.weightKg = weightKg
        self.reps = reps
        self.completedAt = completedAt
        self.rir = rir
    }
}

public struct BodyMetric: Codable, Sendable, Identifiable, Hashable {
    public var id: String
    public var recordedAt: Int
    public var bodyweightKg: Double?
    public var bodyFatPct: Double?
    public var muscleMassKg: Double?

    public init(
        id: String, recordedAt: Int,
        bodyweightKg: Double?, bodyFatPct: Double?, muscleMassKg: Double?
    ) {
        self.id = id
        self.recordedAt = recordedAt
        self.bodyweightKg = bodyweightKg
        self.bodyFatPct = bodyFatPct
        self.muscleMassKg = muscleMassKg
    }
}

public struct UserPrefs: Codable, Sendable, Hashable {
    public var activeSplitId: String?
    public var units: Units
    public var theme: ThemeChoice
    public var onboardingComplete: Bool
    public var restSeconds: Int
    public var accent: String
    public var handle: String?
    public var color: String?
    public var avatarPhoto: String?

    public init(
        activeSplitId: String? = nil,
        units: Units = .kg,
        theme: ThemeChoice = .system,
        onboardingComplete: Bool = false,
        restSeconds: Int = GymDoneConstants.defaultRestSeconds,
        accent: String = GymDoneConstants.defaultAccent,
        handle: String? = nil,
        color: String? = nil,
        avatarPhoto: String? = nil
    ) {
        self.activeSplitId = activeSplitId
        self.units = units
        self.theme = theme
        self.onboardingComplete = onboardingComplete
        self.restSeconds = restSeconds
        self.accent = accent
        self.handle = handle
        self.color = color
        self.avatarPhoto = avatarPhoto
    }
}

/// Ephemeral-but-persisted state of the workout currently being logged. Persisting this
/// is what lets a session — including a running rest timer — survive app relaunch.
public struct ActiveSessionState: Codable, Sendable, Hashable {
    public var sessionId: String
    public var workoutDayId: String
    /// Ordered; includes exercises added just for this workout.
    public var exerciseIds: [String]
    /// The subset of `exerciseIds` that were added for this workout only.
    public var addedExerciseIds: [String]
    public var currentIndex: Int
    /// Wall-clock epoch millis at which rest ends. Wall-clock rather than a countdown so
    /// it stays correct across backgrounding and relaunch.
    public var restEndAt: Int?
    /// Seconds configured for the currently running timer.
    public var restDuration: Int?

    public init(
        sessionId: String, workoutDayId: String, exerciseIds: [String],
        addedExerciseIds: [String], currentIndex: Int,
        restEndAt: Int? = nil, restDuration: Int? = nil
    ) {
        self.sessionId = sessionId
        self.workoutDayId = workoutDayId
        self.exerciseIds = exerciseIds
        self.addedExerciseIds = addedExerciseIds
        self.currentIndex = currentIndex
        self.restEndAt = restEndAt
        self.restDuration = restDuration
    }
}

// MARK: - Constants

public enum GymDoneConstants {
    /// `Session.notes` value that marks an auto-logged rest day.
    public static let restSessionNote = "rest"
    public static let defaultStartWeightKg: Double = 20.0
    public static let restMin = 30
    public static let restMax = 600
    public static let restStep = 30
    public static let defaultRestSeconds = 90
    public static let minDays = 2
    public static let maxDays = 7
    public static let defaultAccent = "lime"
    /// Bumped when the seed catalog changes; drives the merge path in `ensureSeeded`.
    public static let seedVersion = 1
    /// Key the web app persists under. Kept identical so a raw dump is portable.
    public static let storageKey = "get-gym-done:v1"
}
