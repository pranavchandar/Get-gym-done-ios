import SwiftUI
import GymDoneKit

@main
struct GetGymDoneApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// Phase 0 placeholder. This exists so the toolchain — XcodeGen, xcodebuild, the
/// simulator, the UI-test screenshot pipeline — can be proven end to end before any
/// real screen depends on it. Replaced in Phase 3 by the onboarding/tab-shell router
/// described in docs/ARCHITECTURE.md §6.
struct RootView: View {
    private let seedCount = SeedCatalog.exerciseCount()

    var body: some View {
        ZStack {
            Color(red: 0.039, green: 0.039, blue: 0.035).ignoresSafeArea()
            VStack(spacing: 12) {
                Text("GET GYM DONE")
                    .font(.custom("Anton-Regular", size: 40))
                    .foregroundStyle(Color(red: 0.718, green: 0.937, blue: 0.035))
                Text("toolchain smoke test")
                    .font(.custom("Inter-Regular", size: 15))
                    .foregroundStyle(.white.opacity(0.65))
                Text("\(seedCount) exercises seeded")
                    .font(.custom("Inter-SemiBold", size: 13))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .accessibilityIdentifier("root-smoke")
    }
}
