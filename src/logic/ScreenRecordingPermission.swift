import Cocoa

class ScreenRecordingPermission {
    static var status = PermissionStatus.notGranted
    // Recheck on capture queues; UI reads the cached status to avoid synchronous TCC calls.
    static var canCapture: Bool { status == .granted && detect() == .granted }

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    // Only the Screen Recording settings button may call this; polling must never request access.
    static func request() {
        if #available(macOS 10.15, *), !CGPreflightScreenCaptureAccess() {
            CGRequestScreenCaptureAccess()
        }
    }

    private static func detect() -> PermissionStatus {
        if #available(macOS 10.15, *) {
            // Unlike SCShareableContent and CGDisplayStream, preflight never prompts. On older macOS
            // versions its result can be cached for the process lifetime; granting access may need a restart.
            return CGPreflightScreenCaptureAccess() ? .granted :
                (Preferences.screenRecordingPermissionSkipped ? .skipped : .notGranted)
        }
        return .granted
    }
}

enum PermissionStatus {
    case granted
    case notGranted
    case skipped
}
