import ApplicationServices.HIServices.AXRoleConstants
import CoreGraphics

/// Pure classification for macOS 27 system alert/confirmation surfaces.
///
/// Those surfaces are AX dialog windows at the WindowServer modal-panel layer
/// (`kCGWindowLayer == 8`), not attached to a parent window. Capturing one with
/// ScreenCaptureKit blanks it, so it must not be captured.
///
/// The visible surface is a pair of `CGWindow`s owned by the same process: the
/// content window above, and a larger, concentric companion window behind it.
/// The pair is a useful confirmation, but it is deliberately not required:
/// Finder creates the content window a few milliseconds before its companion is
/// registered. Requiring the companion allows one capture in that gap, which is
/// exactly enough to blank the dialog. The companion is still exposed here so
/// callers can log/verify it.
///
/// The rule stays narrow: ordinary windows are layer 0, and sheets are attached
/// to a parent (`parentWid != 0`). If a future macOS changes these properties,
/// this classifier fails open (the window is captured again), which is safer
/// than excluding ordinary windows.
class WindowCaptureExclusionTestable {
    struct CapturableWindow {
        let wid: CGWindowID
        let pid: pid_t
        let parentWid: CGWindowID
        let axRole: String?
        let axSubrole: String?
    }

    struct WindowServerWindow {
        let wid: CGWindowID
        let pid: pid_t
        let layer: Int
        let bounds: CGRect
        let onscreen: Bool
    }

    static let modalPanelLevel = CGWindowLevelForKey(.modalPanelWindow)
    private static let concentricTolerance: CGFloat = 1

    static func isSystemAlertContentWindow(_ window: CapturableWindow, _ windows: [WindowServerWindow]) -> Bool {
        guard window.parentWid == 0,
              window.axRole == kAXWindowRole,
              window.axSubrole == kAXDialogSubrole,
              let content = windows.first(where: { $0.wid == window.wid && $0.pid == window.pid }),
              content.layer == Int(modalPanelLevel) else { return false }
        return true
    }

    /// The companion is the larger, concentric window drawn behind the alert.
    /// It is not required by `isSystemAlertContentWindow`; see the type comment.
    static func alertCompanion(of content: WindowServerWindow,
                               in windows: [WindowServerWindow]) -> WindowServerWindow? {
        windows.first { isCompanion($0, of: content) }
    }

    static func isCompanion(_ candidate: WindowServerWindow, of content: WindowServerWindow) -> Bool {
        guard candidate.wid != content.wid,
              candidate.pid == content.pid,
              candidate.layer == content.layer,
              !content.onscreen,
              candidate.onscreen,
              candidate.bounds.width > content.bounds.width,
              candidate.bounds.height > content.bounds.height else { return false }
        // The pair stays concentric during the scale-in animation, when the
        // 75-point resting margin is temporarily scaled down.
        return abs(candidate.bounds.midX - content.bounds.midX) <= concentricTolerance
            && abs(candidate.bounds.midY - content.bounds.midY) <= concentricTolerance
    }
}
