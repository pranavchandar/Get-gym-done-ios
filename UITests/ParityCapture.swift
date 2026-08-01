import XCTest

/// Shared plumbing for the screenshot parity harness.
///
/// The development environment for this project has no simulator, so these captures
/// are the only way the UI is ever seen. Each one is attached under the exact filename
/// of its counterpart in `docs/parity/web-reference/`, and CI exports the attachments,
/// diffs them and commits both back to the branch.
class ParityCaptureCase: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    /// Launches the app with a frozen clock and a deterministic fixture store, matching
    /// the state the web reference shots were captured against.
    @discardableResult
    func launchApp(
        fixture: String = "populated",
        theme: String = "dark",
        accent: String = "lime"
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["GGD_UI_TEST_FIXTURE"] = fixture
        app.launchEnvironment["GGD_UI_TEST_THEME"] = theme
        app.launchEnvironment["GGD_UI_TEST_ACCENT"] = accent
        // Matches the instant the web corpus was captured so streaks, calendars and
        // "up next" resolve identically on both sides.
        app.launchEnvironment["GGD_UI_TEST_NOW"] = "1785600000000"
        app.launchArguments += ["-AppleAnimationsEnabled", "NO", "-UIAnimationDragCoefficient", "0"]
        app.launch()
        return app
    }

    /// Captures the full screen and attaches it as `<name>.png`.
    func capture(_ app: XCUIApplication, as name: String, file: StaticString = #filePath, line: UInt = #line) {
        // Settle before capturing: an in-flight transition is the usual cause of a
        // flaky one-off diff.
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "app was not in the foreground when capturing \(name)",
            file: file, line: line
        )
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(name).png"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
