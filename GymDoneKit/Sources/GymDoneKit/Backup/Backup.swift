import Foundation

// BackupFile v2 + Android interop — a direct port of `backup/backup.ts`, plus
// DEFECT #1 (see docs/DEFECT-LEDGER.md #1 and docs/ARCHITECTURE.md §8): the web's
// `parseBackup` accepts *any* JSON object and casts it to `BackupFile` with zero
// structural validation, so importing an unrelated JSON file silently wipes all user
// data and still reports success. `Backup.parse` below validates `version == 2` and
// that the required arrays are present before returning, throwing a descriptive
// `Backup.BackupError` otherwise; `Backup.safetyExport` writes a timestamped copy of
// the current store before any destructive replace, and `Backup.apply` calls it
// automatically so the fix can't be forgotten by a call site.

// MARK: - Opaque JSON passthrough (for `exerciseMedia`)

/// A minimal, fully-generic JSON value — used only for `BackupFile.exerciseMedia`
/// (TS: `unknown[]`). The app never reads an entry's shape (an Android export may
/// contain real media rows; our own exports always emit `[]`), so this exists purely
/// so decoding an Android backup can't fail on data we don't understand, without us
/// having to model that data.
/// `indirect` is not needed here even though the type is recursive: `Array` and
/// `Dictionary` are already heap-backed (a fixed-size handle to a buffer), so wrapping
/// `JSONValue` in `[JSONValue]`/`[String: JSONValue]` doesn't create the unbounded-size
/// problem `indirect` exists to solve — only a case holding `JSONValue` directly would.
public enum JSONValue: Codable, Sendable, Equatable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let v = try? container.decode(Bool.self) {
            self = .bool(v)
        } else if let v = try? container.decode(Double.self) {
            self = .number(v)
        } else if let v = try? container.decode(String.self) {
            self = .string(v)
        } else if let v = try? container.decode([JSONValue].self) {
            self = .array(v)
        } else if let v = try? container.decode([String: JSONValue].self) {
            self = .object(v)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Unsupported JSON value in exerciseMedia"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null: try container.encodeNil()
        case .bool(let v): try container.encode(v)
        case .number(let v): try container.encode(v)
        case .string(let v): try container.encode(v)
        case .array(let v): try container.encode(v)
        case .object(let v): try container.encode(v)
        }
    }
}

// MARK: - Android-shaped prefs

/// Mirrors `AndroidUserPrefs` in backup.ts. Field names are the Android app's, not the
/// web/iOS app's (`socialHandle`/`socialColor`/`avatarPhoto`/`socialEnabled`/
/// `socialUserId`/`id`), so a backup round-trips losslessly with the Android app.
/// `units`/`theme` stay raw `String` (not `Units`/`ThemeChoice`) so an unexpected value
/// decodes instead of failing the whole backup — `Backup.userPrefs(fromAndroid:)` is
/// where those get validated into the app's real enums, matching `prefsFromBackup` in
/// backup.ts.
public struct AndroidUserPrefs: Codable, Sendable, Hashable {
    public var id: Int
    public var activeSplitId: String?
    public var units: String
    public var theme: String
    public var onboardingComplete: Bool
    public var restSeconds: Int
    public var accent: String
    public var socialEnabled: Bool
    public var socialUserId: String?
    public var socialHandle: String?
    public var socialColor: String?
    public var avatarPhoto: String?

    public init(
        id: Int,
        activeSplitId: String?,
        units: String,
        theme: String,
        onboardingComplete: Bool,
        restSeconds: Int,
        accent: String,
        socialEnabled: Bool,
        socialUserId: String?,
        socialHandle: String?,
        socialColor: String?,
        avatarPhoto: String?
    ) {
        self.id = id
        self.activeSplitId = activeSplitId
        self.units = units
        self.theme = theme
        self.onboardingComplete = onboardingComplete
        self.restSeconds = restSeconds
        self.accent = accent
        self.socialEnabled = socialEnabled
        self.socialUserId = socialUserId
        self.socialHandle = socialHandle
        self.socialColor = socialColor
        self.avatarPhoto = avatarPhoto
    }

    private enum CodingKeys: String, CodingKey {
        case id, activeSplitId, units, theme, onboardingComplete, restSeconds,
             accent, socialEnabled, socialUserId, socialHandle, socialColor, avatarPhoto
    }

    /// Lenient decode: every field falls back to a sensible default instead of failing
    /// the whole backup, because a real-world `userPrefs` payload (Android, or an older
    /// schema) may be missing fields this schema has since added. The per-field
    /// fallback values mirror `prefsFromBackup`'s `raw.field ?? default` in backup.ts.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        activeSplitId = try container.decodeIfPresent(String.self, forKey: .activeSplitId)
        units = try container.decodeIfPresent(String.self, forKey: .units) ?? "kg"
        theme = try container.decodeIfPresent(String.self, forKey: .theme) ?? "system"
        onboardingComplete = try container.decodeIfPresent(Bool.self, forKey: .onboardingComplete) ?? true
        restSeconds = try container.decodeIfPresent(Int.self, forKey: .restSeconds)
            ?? GymDoneConstants.defaultRestSeconds
        accent = try container.decodeIfPresent(String.self, forKey: .accent) ?? GymDoneConstants.defaultAccent
        socialEnabled = try container.decodeIfPresent(Bool.self, forKey: .socialEnabled) ?? false
        socialUserId = try container.decodeIfPresent(String.self, forKey: .socialUserId)
        socialHandle = try container.decodeIfPresent(String.self, forKey: .socialHandle)
        socialColor = try container.decodeIfPresent(String.self, forKey: .socialColor)
        avatarPhoto = try container.decodeIfPresent(String.self, forKey: .avatarPhoto)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(activeSplitId, forKey: .activeSplitId)
        try container.encode(units, forKey: .units)
        try container.encode(theme, forKey: .theme)
        try container.encode(onboardingComplete, forKey: .onboardingComplete)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(accent, forKey: .accent)
        try container.encode(socialEnabled, forKey: .socialEnabled)
        try container.encode(socialUserId, forKey: .socialUserId)
        try container.encode(socialHandle, forKey: .socialHandle)
        try container.encode(socialColor, forKey: .socialColor)
        try container.encode(avatarPhoto, forKey: .avatarPhoto)
    }
}

// MARK: - BackupFile v2

/// Mirrors the `BackupFile` interface in backup.ts.
public struct BackupFile: Codable, Sendable {
    public var version: Int
    public var exportedAt: Int
    public var exercises: [Exercise]
    public var splits: [Split]
    public var workoutDays: [WorkoutDay]
    public var dayExercises: [DayExercise]
    public var sessions: [Session]
    public var setLogs: [SetLog]
    public var bodyMetrics: [BodyMetric]
    public var userPrefs: AndroidUserPrefs?
    public var exerciseMedia: [JSONValue]

    public init(
        version: Int,
        exportedAt: Int,
        exercises: [Exercise],
        splits: [Split],
        workoutDays: [WorkoutDay],
        dayExercises: [DayExercise],
        sessions: [Session],
        setLogs: [SetLog],
        bodyMetrics: [BodyMetric],
        userPrefs: AndroidUserPrefs?,
        exerciseMedia: [JSONValue] = []
    ) {
        self.version = version
        self.exportedAt = exportedAt
        self.exercises = exercises
        self.splits = splits
        self.workoutDays = workoutDays
        self.dayExercises = dayExercises
        self.sessions = sessions
        self.setLogs = setLogs
        self.bodyMetrics = bodyMetrics
        self.userPrefs = userPrefs
        self.exerciseMedia = exerciseMedia
    }

    private enum CodingKeys: String, CodingKey {
        case version, exportedAt, exercises, splits, workoutDays, dayExercises,
             sessions, setLogs, bodyMetrics, userPrefs, exerciseMedia
    }

    /// Every array defaults to `[]` and `exerciseMedia`/`userPrefs` default to
    /// absent/nil if the key is missing — `Backup.parse` is where hard validation of
    /// "is this actually a v2 backup" happens (DEFECT #1); this decoder's job is only
    /// to not blow up on a well-formed-but-sparse payload once that gate is passed.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decode(Int.self, forKey: .version)
        exportedAt = try container.decodeIfPresent(Int.self, forKey: .exportedAt) ?? 0
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        splits = try container.decodeIfPresent([Split].self, forKey: .splits) ?? []
        workoutDays = try container.decodeIfPresent([WorkoutDay].self, forKey: .workoutDays) ?? []
        dayExercises = try container.decodeIfPresent([DayExercise].self, forKey: .dayExercises) ?? []
        sessions = try container.decodeIfPresent([Session].self, forKey: .sessions) ?? []
        setLogs = try container.decodeIfPresent([SetLog].self, forKey: .setLogs) ?? []
        bodyMetrics = try container.decodeIfPresent([BodyMetric].self, forKey: .bodyMetrics) ?? []
        userPrefs = try container.decodeIfPresent(AndroidUserPrefs.self, forKey: .userPrefs)
        exerciseMedia = try container.decodeIfPresent([JSONValue].self, forKey: .exerciseMedia) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(exportedAt, forKey: .exportedAt)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(splits, forKey: .splits)
        try container.encode(workoutDays, forKey: .workoutDays)
        try container.encode(dayExercises, forKey: .dayExercises)
        try container.encode(sessions, forKey: .sessions)
        try container.encode(setLogs, forKey: .setLogs)
        try container.encode(bodyMetrics, forKey: .bodyMetrics)
        try container.encode(userPrefs, forKey: .userPrefs)
        try container.encode(exerciseMedia, forKey: .exerciseMedia)
    }
}

// MARK: - Backup operations

public enum Backup {

    public enum BackupError: Error, CustomStringConvertible, Sendable, Equatable {
        case invalidJSON(String)
        case notAnObject
        case unsupportedVersion(found: Int?)
        case missingField(String)

        public var description: String {
            switch self {
            case .invalidJSON(let detail):
                return "Not a valid backup file: \(detail)"
            case .notAnObject:
                return "Not a valid backup file: expected a JSON object at the top level"
            case .unsupportedVersion(let found):
                if let found {
                    return "Unsupported backup version \(found) (expected 2)"
                }
                return "Not a Get Gym Done backup file (missing \"version\")"
            case .missingField(let field):
                return "Not a valid backup file: missing or malformed \"\(field)\""
            }
        }
    }

    private static let requiredArrayFields = [
        "exercises", "splits", "workoutDays", "dayExercises", "sessions", "setLogs", "bodyMetrics",
    ]

    /// Mirrors `buildBackup` in backup.ts. Unlike the TS original there is no
    /// default-to-global-store parameter — the iOS architecture has no singleton store
    /// to default to (`AppStore` is injected, not a module-level accessor per
    /// ARCHITECTURE.md §5), so callers pass `store.data` explicitly.
    public static func build(from state: StoreData) -> BackupFile {
        let p = state.prefs
        let userPrefs = AndroidUserPrefs(
            id: 0,
            activeSplitId: p.activeSplitId,
            units: p.units.rawValue,
            theme: p.theme.rawValue,
            onboardingComplete: p.onboardingComplete,
            restSeconds: p.restSeconds,
            accent: p.accent,
            socialEnabled: false,
            socialUserId: nil,
            socialHandle: p.handle,
            socialColor: p.color,
            avatarPhoto: p.avatarPhoto
        )
        return BackupFile(
            version: 2,
            exportedAt: nowMillis(),
            exercises: Array(state.exercises.values),
            splits: Array(state.splits.values),
            workoutDays: Array(state.workoutDays.values),
            dayExercises: Array(state.dayExercises.values),
            sessions: Array(state.sessions.values),
            setLogs: Array(state.setLogs.values),
            bodyMetrics: Array(state.bodyMetrics.values),
            userPrefs: userPrefs,
            exerciseMedia: []
        )
    }

    /// Mirrors `serializeBackup` in backup.ts (`JSON.stringify(buildBackup(state),
    /// null, 2)`). Output keys are sorted for deterministic, diffable output — the web
    /// preserves object-literal insertion order instead, so byte-for-byte output won't
    /// match, but nothing depends on that; only round-trip and validation behaviour do.
    public static func serialize(_ state: StoreData) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(build(from: state))
        guard let text = String(data: data, encoding: .utf8) else {
            throw BackupError.invalidJSON("could not encode as UTF-8")
        }
        return text
    }

    // DEFECT #1 — the web's `parseBackup` is `JSON.parse(text)` followed by an
    // unchecked `as BackupFile` cast (`typeof data !== 'object'` is the *only* check),
    // so importing any unrelated JSON object silently "succeeds" and goes on to wipe
    // every dictionary in the store. This validates `version == 2` and that every
    // required array field is present (and actually an array) before decoding, and
    // throws a descriptive `BackupError` otherwise — see `BackupTests.swift` for the
    // rejection cases this exists for.
    public static func parse(_ text: String) throws -> BackupFile {
        let data = Data(text.utf8)

        let jsonObject: Any
        do {
            jsonObject = try JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        } catch {
            throw BackupError.invalidJSON(error.localizedDescription)
        }

        guard let dict = jsonObject as? [String: Any] else {
            throw BackupError.notAnObject
        }

        let rawVersion = dict["version"]
        var version: Int?
        if let v = rawVersion as? Int {
            version = v
        } else if let v = rawVersion as? NSNumber {
            version = v.intValue
        } else if let v = rawVersion as? Double {
            version = Int(v)
        }
        guard version == 2 else {
            throw BackupError.unsupportedVersion(found: version)
        }

        for field in requiredArrayFields {
            guard (dict[field] as? [Any]) != nil else {
                throw BackupError.missingField(field)
            }
        }

        do {
            return try JSONDecoder().decode(BackupFile.self, from: data)
        } catch {
            throw BackupError.invalidJSON("shape did not match BackupFile v2 (\(error.localizedDescription))")
        }
    }

    /// Converts Android-shaped prefs (as read from a parsed backup) into the app's own
    /// `UserPrefs`, validating `theme`/`units` into their closed enums (anything
    /// unrecognised falls back to `.system` / `.kg`) exactly as `prefsFromBackup` does
    /// in backup.ts. Every other field's "absent" fallback already happened in
    /// `AndroidUserPrefs.init(from:)`, so this is a straight rename/re-type from there.
    public static func userPrefs(fromAndroid raw: AndroidUserPrefs?) -> UserPrefs? {
        guard let raw else { return nil }
        let theme: ThemeChoice
        switch raw.theme {
        case ThemeChoice.light.rawValue: theme = .light
        case ThemeChoice.dark.rawValue: theme = .dark
        case ThemeChoice.system.rawValue: theme = .system
        default: theme = .system
        }
        let units: Units = raw.units.lowercased() == Units.lbs.rawValue ? .lbs : .kg
        return UserPrefs(
            activeSplitId: raw.activeSplitId,
            units: units,
            theme: theme,
            onboardingComplete: raw.onboardingComplete,
            restSeconds: raw.restSeconds,
            accent: raw.accent,
            handle: raw.socialHandle,
            color: raw.socialColor,
            avatarPhoto: raw.avatarPhoto
        )
    }

    // DEFECT #1 — writes a timestamped copy of `state` to disk. `Backup.apply` calls
    // this automatically before performing its destructive replace, so a bad import
    // can always be recovered from, unlike the web (which has no export-before-import
    // safety net at all).
    @discardableResult
    public static func safetyExport(
        _ state: StoreData,
        directory: URL? = nil
    ) throws -> URL {
        let base = directory ?? Persistence.defaultFileURL().deletingLastPathComponent()
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        let url = base.appendingPathComponent("safety-export-\(nowMillis()).json", isDirectory: false)
        let text = try serialize(state)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Full wipe + re-insert from a parsed backup, via `AppStore.replaceAll`. Mirrors
    /// `applyBackup` in backup.ts, plus DEFECT #1's automatic safety export first.
    /// Returns the safety-export URL so the caller can surface it ("your previous data
    /// was saved to ... before importing").
    @MainActor
    @discardableResult
    public static func apply(_ file: BackupFile, to store: AppStore) throws -> URL {
        guard file.version == 2 else {
            throw BackupError.unsupportedVersion(found: file.version)
        }

        let exportURL = try safetyExport(store.data)

        var patch = StoreDataPatch()
        patch.exercises = toRecord(file.exercises)
        patch.splits = toRecord(file.splits)
        patch.workoutDays = toRecord(file.workoutDays)
        patch.dayExercises = toRecord(file.dayExercises)
        patch.sessions = toRecord(file.sessions)
        patch.setLogs = toRecord(file.setLogs)
        patch.bodyMetrics = toRecord(file.bodyMetrics)
        patch.prefs = userPrefs(fromAndroid: file.userPrefs)

        store.replaceAll(patch)
        return exportURL
    }

    /// Mirrors `toRecord` in backup.ts. Simpler than the TS version: by the time an
    /// array of e.g. `Exercise` exists here, `JSONDecoder` has already required every
    /// element to have a well-typed, non-null `id` (TS's unchecked cast can't make that
    /// guarantee, hence its extra `item.id != null` check).
    private static func toRecord<T: Identifiable>(_ items: [T]) -> [String: T] where T.ID == String {
        var record: [String: T] = [:]
        for item in items {
            record[item.id] = item
        }
        return record
    }
}
