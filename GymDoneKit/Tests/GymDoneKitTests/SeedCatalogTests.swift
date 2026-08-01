import XCTest
@testable import GymDoneKit

/// Phase 0 gate: the bundled catalog resolves and matches the shape both other
/// implementations ship. Deliberately strict about the counts — if the catalog ever
/// drifts from the web app's copy, this fails before any screen is built on it.
final class SeedCatalogTests: XCTestCase {

    func testSeedResourceResolves() throws {
        let data = try SeedCatalog.rawSeedData()
        XCTAssertGreaterThan(data.count, 10_000, "seed_data.json looks truncated")
    }

    func testCatalogCounts() throws {
        let (splits, exercises) = try SeedCatalog.counts()
        XCTAssertEqual(splits, 7, "expected the 7 preset splits")
        XCTAssertEqual(exercises, 155, "expected the 155-exercise catalog")
    }

    func testExerciseCountConvenience() {
        XCTAssertEqual(SeedCatalog.exerciseCount(), 155)
    }
}
