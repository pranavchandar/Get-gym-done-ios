import Foundation

// Atomic on-disk snapshot store — the iOS equivalent of zustand's `persist` middleware
// (which writes the whole `StoreData` blob to `localStorage["get-gym-done:v1"]" on
// every `set()`). See docs/ARCHITECTURE.md §4.2.
//
// `Persistence` itself only stores a `URL` (unambiguously `Sendable`), so it is cheap
// and safe to capture into the detached background task `AppStore` schedules on every
// mutation — see `AppStore.scheduleSave()`.

/// Reads and writes a single `StoreData` snapshot to `fileURL`, atomically.
public struct Persistence: Sendable {

    public enum PersistenceError: Error, CustomStringConvertible, Sendable {
        case directoryUnavailable(String)
        case writeFailed(String)

        public var description: String {
            switch self {
            case .directoryUnavailable(let detail):
                return "could not create/resolve the snapshot directory: \(detail)"
            case .writeFailed(let detail):
                return "failed to write the snapshot: \(detail)"
            }
        }
    }

    public let fileURL: URL

    /// Default location: `Application Support/get-gym-done/v1.json`. Falls back to the
    /// temporary directory if Application Support can't be resolved (defensive — e.g.
    /// on platforms/sandboxes where it's unavailable), since callers still need *some*
    /// writable location.
    public static func defaultFileURL(fileManager: FileManager = .default) -> URL {
        let base: URL
        if let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ) {
            base = appSupport
        } else {
            base = fileManager.temporaryDirectory
        }
        return base
            .appendingPathComponent("get-gym-done", isDirectory: true)
            .appendingPathComponent("v1.json", isDirectory: false)
    }

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Persistence.defaultFileURL()
    }

    /// Loads the persisted snapshot, or `nil` if none exists yet (first launch) or the
    /// file is unreadable/corrupt.
    ///
    /// A corrupt file is preserved — side-filed next to itself as
    /// `v1.corrupt-<epoch-millis>.json` — rather than silently discarded, and this
    /// returns `nil` so the caller (`AppStore`) falls back to an empty store.
    public func load() -> StoreData? {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        do {
            let raw = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode(StoreData.self, from: raw)
        } catch {
            sideFileCorrupt(fileManager: fileManager)
            return nil
        }
    }

    private func sideFileCorrupt(fileManager: FileManager) {
        let timestamp = Int(Date().timeIntervalSince1970 * 1000)
        let corruptURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("v1.corrupt-\(timestamp).json", isDirectory: false)
        try? fileManager.moveItem(at: fileURL, to: corruptURL)
    }

    /// Encodes and atomically writes `data` to `fileURL`: encode → write to a sibling
    /// `.tmp` file → `FileManager.replaceItemAt`, creating the parent directory first
    /// if needed. Best-effort: a failure (disk full, sandbox denial, ...) is swallowed
    /// rather than thrown, mirroring how a `localStorage.setItem` quota error leaves
    /// the web app's in-memory store as the sole source of truth for the rest of the
    /// session. Use `save(throwing:)` where you need to detect failure explicitly (as
    /// `Backup.safetyExport` does, since a silent failure there would defeat the point).
    public func save(_ data: StoreData) {
        try? saveThrowing(data)
    }

    @discardableResult
    public func saveThrowing(_ data: StoreData) throws -> URL {
        let fileManager = FileManager.default
        let directory = fileURL.deletingLastPathComponent()
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            throw PersistenceError.directoryUnavailable(error.localizedDescription)
        }

        let encoder = JSONEncoder()
        let encoded: Data
        do {
            encoded = try encoder.encode(data)
        } catch {
            throw PersistenceError.writeFailed("encode failed: \(error.localizedDescription)")
        }

        let tempURL = directory.appendingPathComponent(".v1-\(UUID().uuidString).tmp", isDirectory: false)
        do {
            try encoded.write(to: tempURL, options: .atomic)
        } catch {
            throw PersistenceError.writeFailed("temp write failed: \(error.localizedDescription)")
        }

        do {
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
        } catch {
            // `replaceItemAt` documents that it creates `fileURL` if it doesn't already
            // exist, but fall back to a plain move for any filesystem that disagrees.
            do {
                try? fileManager.removeItem(at: fileURL)
                try fileManager.moveItem(at: tempURL, to: fileURL)
            } catch {
                throw PersistenceError.writeFailed("replace failed: \(error.localizedDescription)")
            }
        }
        return fileURL
    }
}
