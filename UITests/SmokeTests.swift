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

    /// Reports the device's logical size. Parity wants 390×844 (iPhone 12/13/14), but
    /// runner images rotate their preinstalled simulators, so this REPORTS rather than
    /// asserts — the CI log is the only way the dev side can learn what it actually ran
    /// on, and failing here would stop the captures that make the run useful.
    ///
    /// If this prints anything other than 390x844, the fix is to re-capture the web
    /// reference corpus at that size (see docs/parity/capture-web-reference.mjs), not
    /// to force a device that the image does not ship.
    func testReportViewportSize() {
        let app = launchApp()
        let frame = app.windows.firstMatch.frame
        let size = "\(Int(frame.width))x\(Int(frame.height))"
        print("PARITY_VIEWPORT \(size)")
        XCTContext.runActivity(named: "viewport \(size)") { _ in }
        if size != "390x844" {
            print("PARITY_VIEWPORT_MISMATCH expected 390x844, got \(size)")
        }
    }
}
