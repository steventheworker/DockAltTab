import XCTest

final class ScreenRecordingPermissionTests: XCTestCase {
    override func setUp() {
        super.setUp()
        ScreenCaptureAccessMock.granted = false
        ScreenCaptureAccessMock.preflightCalls = 0
        ScreenCaptureAccessMock.requestCalls = 0
        Preferences.screenRecordingPermissionSkipped = false
        ScreenRecordingPermission.status = .notGranted
    }

    func testFreshLaunchChecksWithoutRequestingAccess() {
        XCTAssertEqual(ScreenRecordingPermission.update(), .notGranted)
        XCTAssertFalse(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenCaptureAccessMock.preflightCalls, 1)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testSkippedPermissionRemainsSilentAcrossRepeatedChecks() {
        Preferences.screenRecordingPermissionSkipped = true
        for _ in 0..<10 {
            XCTAssertEqual(ScreenRecordingPermission.update(), .skipped)
            XCTAssertFalse(ScreenRecordingPermission.canCapture)
        }
        XCTAssertEqual(ScreenCaptureAccessMock.preflightCalls, 10)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testGrantedPermissionAllowsCaptureWithoutRequestingAccess() {
        ScreenCaptureAccessMock.granted = true
        XCTAssertEqual(ScreenRecordingPermission.update(), .granted)
        XCTAssertTrue(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenCaptureAccessMock.preflightCalls, 2)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testSkipDoesNotOverrideAnExistingGrant() {
        Preferences.screenRecordingPermissionSkipped = true
        ScreenCaptureAccessMock.granted = true
        XCTAssertEqual(ScreenRecordingPermission.update(), .granted)
        XCTAssertTrue(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testCaptureRequiresAPreviouslyConfirmedGrant() {
        ScreenCaptureAccessMock.granted = true
        XCTAssertFalse(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenCaptureAccessMock.preflightCalls, 0)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testRevocationBlocksQueuedCaptureBeforeNextPermissionPoll() {
        ScreenCaptureAccessMock.granted = true
        ScreenRecordingPermission.update()
        ScreenCaptureAccessMock.granted = false
        XCTAssertEqual(ScreenRecordingPermission.status, .granted)
        XCTAssertFalse(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenRecordingPermission.update(), .notGranted)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testRevocationFallsBackToSkippedWhenOptedOut() {
        Preferences.screenRecordingPermissionSkipped = true
        ScreenCaptureAccessMock.granted = true
        ScreenRecordingPermission.update()
        ScreenCaptureAccessMock.granted = false
        XCTAssertFalse(ScreenRecordingPermission.canCapture)
        XCTAssertEqual(ScreenRecordingPermission.update(), .skipped)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }

    func testExplicitRequestIsNotRepeatedByPollingAfterDenial() {
        ScreenRecordingPermission.request()
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 1)
        for _ in 0..<10 {
            XCTAssertEqual(ScreenRecordingPermission.update(), .notGranted)
            XCTAssertFalse(ScreenRecordingPermission.canCapture)
        }
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 1)
    }

    func testRequestDoesNotPromptWhenAlreadyGranted() {
        ScreenCaptureAccessMock.granted = true
        ScreenRecordingPermission.request()
        XCTAssertEqual(ScreenCaptureAccessMock.preflightCalls, 1)
        XCTAssertEqual(ScreenCaptureAccessMock.requestCalls, 0)
    }
}

private enum ScreenCaptureAccessMock {
    static var granted = false
    static var preflightCalls = 0
    static var requestCalls = 0
}

// Module-local substitutes shadow CoreGraphics in the unit-test target only. Never touch real TCC in tests.
func CGPreflightScreenCaptureAccess() -> Bool {
    ScreenCaptureAccessMock.preflightCalls += 1
    return ScreenCaptureAccessMock.granted
}

@discardableResult
func CGRequestScreenCaptureAccess() -> Bool {
    ScreenCaptureAccessMock.requestCalls += 1
    return ScreenCaptureAccessMock.granted
}
