import XCTest

/// Phase 0 gate. Proves the whole capture pipeline works — app launches on the
/// simulator, a screenshot is taken, the attachment survives into the .xcresult,
/// CI exports it under the right filename and commits it back — before any real
/// screen depends on that pipeline.
final class SmokeTests: ParityCaptureCase {

    func testAppLaunchesAndCaptures() {
        let app = launchApp()
        XCTAssertTrue(
            app.otherElements["root-smoke"].waitForExistence(timeout: 15)
                || app.staticTexts["GET GYM DONE"].waitForExistence(timeout: 5),
            "root view never appeared"
        )
        capture(app, as: "00-smoke")
    }

    /// Records the device's logical size in the test log. Parity needs 390×844
    /// (iPhone 12/13/14); anything else means the diff is not pixel-comparable and
    /// the CI log is the only place that can be observed from the dev side.
    func testViewportIsParitySized() {
        let app = launchApp()
        let frame = app.windows.firstMatch.frame
        print("PARITY_VIEWPORT \(Int(frame.width))x\(Int(frame.height))")
        XCTAssertEqual(frame.width, 390, accuracy: 1, "expected a 390pt-wide device")
        XCTAssertEqual(frame.height, 844, accuracy: 1, "expected an 844pt-tall device")
    }
}
