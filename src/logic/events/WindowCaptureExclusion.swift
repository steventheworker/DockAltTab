import Cocoa

struct WindowServerSnapshot {
    let windows: [WindowCaptureExclusionTestable.WindowServerWindow]

    init() {
        let modalPanelLevel = Int(CGWindowLevelForKey(.modalPanelWindow))
        let list = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [CGWindow] ?? []
        windows = list.compactMap { window in
            guard let wid = window.id(),
                  let pid = window.ownerPID(),
                  let layer = window.layer(),
                  layer == modalPanelLevel,
                  let bounds = window.bounds() else { return nil }
            return WindowCaptureExclusionTestable.WindowServerWindow(
                wid: wid, pid: pid, layer: layer, bounds: bounds, onscreen: window.isOnscreen())
        }
    }
}

private extension CGWindow {
    func isOnscreen() -> Bool {
        (self[kCGWindowIsOnscreen] as? NSNumber)?.boolValue ?? false
    }
}

extension Window {
    var captureEligibilityInfo: WindowCaptureExclusionTestable.CapturableWindow {
        WindowCaptureExclusionTestable.CapturableWindow(
            wid: cgWindowId ?? 0,
            pid: application.pid,
            parentWid: parentWid,
            axRole: axRole,
            axSubrole: axSubrole)
    }
}

enum WindowCaptureExclusion {
    static func isSystemAlertContentWindow(_ window: Window, _ layer: Int) -> Bool {
        window.isSystemAlertCandidate && layer == Int(CGWindowLevelForKey(.modalPanelWindow))
    }

    /// macOS 27.2.1 blanks certain system alert/confirmation surfaces after a
    /// single ScreenCaptureKit window capture. Skip those windows while keeping
    /// them in `Windows.list` so the switcher and keyboard navigation are intact.
    static func eligibleWindows(_ windows: [Window]) -> [Window] {
        guard windows.contains(where: { $0.isSystemAlertCandidate }) else { return windows }
        let snapshot = WindowServerSnapshot()
        return windows.filter { window in
            let info = window.captureEligibilityInfo
            let excluded = WindowCaptureExclusionTestable.isSystemAlertContentWindow(info, snapshot.windows)
            if excluded {
                let companion = snapshot.windows.first { $0.wid == info.wid && $0.pid == info.pid }
                    .flatMap { WindowCaptureExclusionTestable.alertCompanion(of: $0, in: snapshot.windows) }
                Logger.debug {
                    "not capturing system alert window: \(window.debugId) companion:\(companion?.wid.description ?? "none")"
                }
            }
            return !excluded
        }
    }
}
