import Foundation

// Seed catalog build — a direct port of `store/seed.ts`.
//
// Resource loading itself (`Bundle.module` lookup, byte-count/shape smoke checks) stays
// in `SeedCatalog.swift` (the Phase 0 stub) — this file builds on top of
// `SeedCatalog.rawSeedData()` rather than duplicating it, per the task's guidance. The
// type here is named `SeedCatalogData` (not `SeedCatalog`, which the Phase 0 stub
// already uses as its enum name) to avoid a redeclaration clash.

/// The four entity dictionaries produced from `seed_data.json` — mirrors the
/// `SeedCatalog` interface in seed.ts.
public struct SeedCatalogData: Sendable {
    public let splits: [String: Split]
    public let workoutDays: [String: WorkoutDay]
    public let dayExercises: [String: DayExercise]
    public let exercises: [String: Exercise]

    public init(
        splits: [String: Split],
        workoutDays: [String: WorkoutDay],
        dayExercises: [String: DayExercise],
        exercises: [String: Exercise]
    ) {
        self.splits = splits
        self.workoutDays = workoutDays
        self.dayExercises = dayExercises
        self.exercises = exercises
    }
}

// MARK: - Raw JSON shape (private decode targets)
//
// Every field beyond the entity's identity is decoded as Optional here even where
// seed_data.json always populates it in practice, exactly mirroring seed.ts's
// defensive `se.field ?? default` chains — so a hand-edited or future seed file that
// omits a descriptive field degrades gracefully instead of failing the whole decode.

private struct RawDayExercise: Decodable {
    let exerciseId: String
    let orderIndex: Int
    let sets: Int
    let repsLow: Int
    let repsHigh: Int
}

private struct RawDay: Decodable {
    let id: String
    let dayNumber: Int
    let name: String
    let muscleGroups: [String]?
    let exercises: [RawDayExercise]?
    let isRestDay: Bool?
}

private struct RawSplit: Decodable {
    let id: String
    let name: String
    let dayCount: Int
    let days: [RawDay]
}

private struct RawExercise: Decodable {
    let id: String
    let name: String
    let primaryMuscle: String
    let secondaryMuscles: [String]?
    let illustrationFilename: String?
    let formCues: [String]?
    let equipment: String?
    let defaultSets: Int?
    let defaultRepsLow: Int?
    let defaultRepsHigh: Int?
}

private struct RawSeedRoot: Decodable {
    let splits: [RawSplit]
    let exercises: [RawExercise]
}

/// Seed catalog build, seed version, and the muscle/equipment option lists used by the
/// custom-exercise form. Mirrors `seed.ts`'s module-level exports.
public enum Seed {

    /// Bumped when the seed catalog changes; drives the merge path in
    /// `AppStore.ensureSeeded()`. Mirrors `SEED_VERSION` in seed.ts. Kept equal to
    /// `GymDoneConstants.seedVersion` (the single source of truth already established
    /// in Types.swift) rather than redefining it here.
    public static let version: Int = GymDoneConstants.seedVersion

    /// Mirrors `dayExerciseId` in seed.ts — the synthesized id for a day's exercise row.
    public static func dayExerciseId(dayId: String, exerciseId: String, orderIndex: Int) -> String {
        "\(dayId)_\(exerciseId)_\(orderIndex)"
    }

    private static func loadRoot() throws -> RawSeedRoot {
        let raw = try SeedCatalog.rawSeedData()
        return try JSONDecoder().decode(RawSeedRoot.self, from: raw)
    }

    /// Builds the four seed dictionaries from the bundled `seed_data.json`. Mirrors
    /// `buildSeedCatalog()` in seed.ts.
    ///
    /// Throwing (unlike the TS original, which is infallible because the JSON is
    /// bundled at compile time) because on iOS the resource is read and decoded at
    /// runtime; `AppStore.ensureSeeded()` treats a failure here as "seed data
    /// unavailable" and no-ops rather than crashing, since `seed_data.json` shipping
    /// correctly is already covered by `SeedCatalogTests` and a CI checksum.
    public static func buildCatalog() throws -> SeedCatalogData {
        let root = try loadRoot()

        var exercises: [String: Exercise] = [:]
        exercises.reserveCapacity(root.exercises.count)
        for se in root.exercises {
            exercises[se.id] = Exercise(
                id: se.id,
                name: se.name,
                primaryMuscle: se.primaryMuscle,
                secondaryMuscles: se.secondaryMuscles ?? [],
                illustrationFilename: se.illustrationFilename ?? "",
                formCues: se.formCues ?? [],
                equipment: se.equipment ?? "Other",
                defaultSets: se.defaultSets ?? 3,
                defaultRepsLow: se.defaultRepsLow ?? 8,
                defaultRepsHigh: se.defaultRepsHigh ?? 12
            )
        }

        var splits: [String: Split] = [:]
        var workoutDays: [String: WorkoutDay] = [:]
        var dayExercises: [String: DayExercise] = [:]
        for ss in root.splits {
            splits[ss.id] = Split(id: ss.id, name: ss.name, dayCount: ss.dayCount, isCustom: false)
            for sd in ss.days {
                workoutDays[sd.id] = WorkoutDay(
                    id: sd.id,
                    splitId: ss.id,
                    dayNumber: sd.dayNumber,
                    name: sd.name,
                    muscleGroups: sd.muscleGroups ?? [],
                    isRestDay: sd.isRestDay ?? false
                )
                for de in sd.exercises ?? [] {
                    let id = dayExerciseId(dayId: sd.id, exerciseId: de.exerciseId, orderIndex: de.orderIndex)
                    dayExercises[id] = DayExercise(
                        id: id,
                        workoutDayId: sd.id,
                        exerciseId: de.exerciseId,
                        orderIndex: de.orderIndex,
                        prescribedSets: de.sets,
                        prescribedRepsLow: de.repsLow,
                        prescribedRepsHigh: de.repsHigh
                    )
                }
            }
        }

        return SeedCatalogData(
            splits: splits, workoutDays: workoutDays, dayExercises: dayExercises, exercises: exercises
        )
    }

    /// Muscle names appearing in the seed catalog (primary or secondary), sorted.
    /// Mirrors `seedMuscles()` in seed.ts.
    public static func muscles() throws -> [String] {
        let root = try loadRoot()
        var set = Set<String>()
        for e in root.exercises {
            set.insert(e.primaryMuscle)
            for m in e.secondaryMuscles ?? [] { set.insert(m) }
        }
        return set.sorted()
    }

    /// Equipment options appearing in the seed catalog, sorted. Mirrors
    /// `seedEquipment()` in seed.ts.
    public static func equipmentOptions() throws -> [String] {
        let root = try loadRoot()
        var set = Set<String>()
        for e in root.exercises { set.insert(e.equipment ?? "Other") }
        return set.sorted()
    }
}
