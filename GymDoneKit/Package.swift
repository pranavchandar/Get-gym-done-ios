// swift-tools-version: 5.9
import PackageDescription

// GymDoneKit holds every piece of logic that carries behavioural-accuracy risk:
// domain maths, the store, selectors, seeding, persistence and the backup format.
// It deliberately has no SwiftUI/UIKit dependency so it builds and tests on Linux,
// which is the only fast feedback loop available to this project (the app target
// itself can only be compiled on a macOS CI runner).
let package = Package(
    name: "GymDoneKit",
    platforms: [.iOS(.v17), .macOS(.v13)],
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
