import Cocoa

// macOS has some privacy restrictions. The user needs to grant certain permissions, app by app, in System Preferences > Security & Privacy
class SystemPermissions {
    static var preStartupPermissionsPassed = false
    private static var timer: DispatchSourceTimer!
    private static var timerIsFrequent = false

    static func ensurePermissionsAreGranted() {
        timer = DispatchSource.makeTimerSource(queue: BackgroundWork.permissionsCheckOnTimerQueue.strongUnderlyingQueue)
        timer.setEventHandler(handler: checkPermissionsOnTimer)
        setImmediateTimer()
        timer.resume()
    }

    private static func checkPermissionsOnTimer() {
        AccessibilityPermission.update()
        let previousScreenRecordingStatus = ScreenRecordingPermission.status
        ScreenRecordingPermission.update()
        let isPermissionsWindowVisible = PermissionsWindow.shared?.isVisible ?? false
        Logger.debug { "accessibility:\(AccessibilityPermission.status) screenRecording:\(ScreenRecordingPermission.status)" }
        if !preStartupPermissionsPassed {
            checkPermissionsPreStartup()
        } else {
            checkPermissionsPostStartup()
            if isPermissionsWindowVisible && !timerIsFrequent {
                setFrequentTimer()
            } else if !isPermissionsWindowVisible && timerIsFrequent {
                setInfrequentTimer()
            }
        }
        DispatchQueue.main.async {
            if previousScreenRecordingStatus == .granted && ScreenRecordingPermission.status != .granted {
                Windows.clearThumbnails()
            }
            Menubar.togglePermissionCallout(ScreenRecordingPermission.status != .granted)
            if PermissionsWindow.shared != nil {
                PermissionsWindow.updatePermissionViews()
            }
        }
    }

    private static func checkPermissionsPreStartup() {
        if AccessibilityPermission.status != .notGranted && ScreenRecordingPermission.status != .notGranted {
            DispatchQueue.main.async {
                guard !preStartupPermissionsPassed else { return }
                preStartupPermissionsPassed = true
                PermissionsWindow.shared?.close()
                setInfrequentTimer()
                App.continueAppLaunchAfterPermissionsAreGranted()
            }
        } else {
            DispatchQueue.main.async {
                App.showPermissionsWindow()
            }
        }
    }

    private static func checkPermissionsPostStartup() {
        if AccessibilityPermission.status == .notGranted {
            Logger.error { "Accessibility permission revoked while DockAltTab was running; restarting" }
            DispatchQueue.main.async { App.restart() }
        }
    }

    static func setInfrequentTimer() {
        timerIsFrequent = false
        timer.schedule(deadline: .now() + 5, repeating: 5, leeway: .seconds(1))
    }

    static func setFrequentTimer() {
        timerIsFrequent = true
        timer.schedule(deadline: .now(), repeating: 0.5, leeway: .milliseconds(500))
    }

    private static func setImmediateTimer() {
        timerIsFrequent = false
        timer.schedule(deadline: .now(), repeating: .never, leeway: .never)
    }
}

class AccessibilityPermission {
    static var status = PermissionStatus.notGranted

    @discardableResult
    static func update() -> PermissionStatus {
        status = detect()
        return status
    }

    private static func detect() -> PermissionStatus {
        return AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeRetainedValue(): false] as CFDictionary) ? .granted : .notGranted
    }
}
