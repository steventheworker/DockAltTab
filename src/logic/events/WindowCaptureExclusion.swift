import Cocoa

struct WindowServerSnapshot {
    let windows: [WindowCaptureExclusionTestable.WindowServerWindow]

    init() {
        let list = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [CGWindow] ?? []
        let wids = list.compactMap { $0.id() }
        let parents = CGWindowID.parents(of: wids)
        windows = list.compactMap { window in
            guard let wid = window.id(),
                  let pid = window.ownerPID(),
                  let layer = window.layer(),
                  let bounds = window.bounds() else { return nil }
            return WindowCaptureExclusionTestable.WindowServerWindow(
                wid: wid,
                pid: pid,
                parentWid: parents[wid] ?? 0,
                layer: layer,
                bounds: bounds,
                onscreen: window.isOnscreen())
        }
    }

    func window(for wid: CGWindowID, pid: pid_t) -> WindowCaptureExclusionTestable.WindowServerWindow? {
        windows.first { $0.wid == wid && $0.pid == pid }
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
            axRole: axRole,
            axSubrole: axSubrole)
    }
}

enum WindowCaptureExclusion {
    /// Re-check a candidate against a fresh WindowServer snapshot immediately
    /// before capture. `SCWindow` objects are cached, and a quickly re-opened
    /// dialog can reuse a wid; the cached layer/parent can be stale. If the
    /// candidate has disappeared from the snapshot, skip this attempt (fail
    /// closed) rather than risk blanking a freshly-created alert.
    static func isSystemAlertContentWindow(_ window: Window) -> Bool {
        guard window.isSystemAlertCandidate else { return false }
        let snapshot = WindowServerSnapshot()
        guard let content = snapshot.window(for: window.cgWindowId ?? 0, pid: window.application.pid) else {
            Logger.debug { "skipping capture: alert candidate missing from window-server snapshot: \(window.debugId)" }
            return true
        }
        let excluded = WindowCaptureExclusionTestable.isSystemAlertContentWindow(window.captureEligibilityInfo, snapshot.windows)
        Logger.debug {
            "capture-time alert check: \(window.debugId) layer:\(content.layer) parent:\(content.parentWid) role:\(window.axRole ?? "nil") sub:\(window.axSubrole ?? "nil") excluded:\(excluded)"
        }
        return excluded
    }

    /// macOS 27.2.1 blanks certain top-level modal alert/dialog windows after a
    /// single ScreenCaptureKit window capture. Exclude them on all macOS versions
    /// while keeping them in `Windows.list` so switcher and keyboard navigation
    /// stay intact.
    static func eligibleWindows(_ windows: [Window]) -> [Window] {
        guard windows.contains(where: { $0.isSystemAlertCandidate }) else { return windows }
        let snapshot = WindowServerSnapshot()
        return windows.filter { window in
            let info = window.captureEligibilityInfo
            let excluded = WindowCaptureExclusionTestable.isSystemAlertContentWindow(info, snapshot.windows)
            if excluded {
                let content = snapshot.window(for: info.wid, pid: info.pid)
                let companion = content.flatMap { WindowCaptureExclusionTestable.alertCompanion(of: $0, in: snapshot.windows) }
                Logger.debug {
                    "not capturing system alert window: \(window.debugId) layer:\(content?.layer.description ?? "none") parent:\(content?.parentWid.description ?? "none") companion:\(companion?.wid.description ?? "none")"
                }
            }
            return !excluded
        }
    }
}
