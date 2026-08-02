// swift-tools-version: 5.9
import PackageDescription

// GymDoneKit holds every piece of logic that carries behavioural-accuracy risk:
// domain maths, the store, selectors, seeding, persistence and the backup format.
// It deliberately has no SwiftUI/UIKit dependency so it builds and tests on Linux,
// which is the only fast feedback loop available to this project (the app target
// itself can only be compiled on a macOS CI runner).
let package = Package(
    name: "GymDoneKit",
    // macOS 14 (not 13) because AppStore.swift uses `@Observable`/Observation, which
    // requires macOS 14 / iOS 17. Bumped from .v13 as part of the Store/Backup port.
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "GymDoneKit", targets: ["GymDoneKit"])
    ],
    targets: [
        .target(
            name: "GymDoneKit",
            resources: [.copy("Resources/seed_data.json")]
        ),
        .testTarget(
            name: "GymDoneKitTests",
            dependencies: ["GymDoneKit"],
            resources: [.copy("Vectors")]
        )
    ]
)
