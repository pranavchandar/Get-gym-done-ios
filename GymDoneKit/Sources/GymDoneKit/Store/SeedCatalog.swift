import Foundation

/// Phase 0 stub. Its only job right now is to prove the bundled `seed_data.json`
/// resource resolves correctly from both the SwiftPM test runner and the app bundle —
/// resource lookup is the single most common way a package like this breaks silently.
/// Phase 1 replaces this with the full port of `store/seed.ts`.
public enum SeedCatalog {

    public enum SeedError: Error, CustomStringConvertible {
        case resourceMissing
        case malformed(String)

        public var description: String {
            switch self {
            case .resourceMissing:
                return "seed_data.json is not present in the GymDoneKit bundle"
            case .malformed(let detail):
                return "seed_data.json is malformed: \(detail)"
            }
        }
    }

    public static func rawSeedData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "seed_data", withExtension: "json") else {
            throw SeedError.resourceMissing
        }
        return try Data(contentsOf: url)
    }

    /// Number of exercises in the seed catalog. Expected to be 155 — the catalog is
    /// byte-identical to the web and Android apps' copy and CI asserts its SHA-256.
    public static func exerciseCount() -> Int {
        (try? counts().exercises) ?? -1
    }

    public static func counts() throws -> (splits: Int, exercises: Int) {
        let data = try rawSeedData()
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let splits = root["splits"] as? [Any],
            let exercises = root["exercises"] as? [Any]
        else {
            throw SeedError.malformed("expected top-level `splits` and `exercises` arrays")
        }
        return (splits.count, exercises.count)
    }
}
