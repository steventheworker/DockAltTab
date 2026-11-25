import ApplicationServices.HIServices.AXRoleConstants
import CoreGraphics
import Foundation

@main
struct ClassifierTests {
    static func main() {
        var failures = 0
        func check(_ condition: Bool, _ name: String) {
            if condition {
                print("PASS \(name)")
            } else {
                print("FAIL \(name)")
                failures += 1
            }
        }
        let alertLayer = Int(CGWindowLevelForKey(.modalPanelWindow))
        let screenSaverLayer = Int(CGWindowLevelForKey(.screenSaverWindow))

        func content(_ wid: CGWindowID, _ pid: pid_t = 100, _ role: String? = kAXWindowRole,
                     _ subrole: String? = kAXDialogSubrole)
            -> WindowCaptureExclusionTestable.CapturableWindow {
            WindowCaptureExclusionTestable.CapturableWindow(wid: wid, pid: pid, axRole: role, axSubrole: subrole)
        }
        func server(_ wid: CGWindowID, _ pid: pid_t = 100, _ layer: Int = 8, _ x: CGFloat, _ y: CGFloat,
                    _ width: CGFloat, _ height: CGFloat, _ onscreen: Bool = true, parent: CGWindowID = 0)
            -> WindowCaptureExclusionTestable.WindowServerWindow {
            WindowCaptureExclusionTestable.WindowServerWindow(
                wid: wid, pid: pid, parentWid: parent, layer: layer,
                bounds: CGRect(x: x, y: y, width: width, height: height), onscreen: onscreen)
        }
        func excluded(_ window: WindowCaptureExclusionTestable.CapturableWindow,
                      _ windows: [WindowCaptureExclusionTestable.WindowServerWindow]) -> Bool {
            WindowCaptureExclusionTestable.isSystemAlertContentWindow(window, windows)
        }

        // AppleScript `display alert`: content 260x202 at 725,221; companion 410x352 at 650,146.
        let appleScriptAlert = [server(1, 100, alertLayer, 725, 221, 260, 202, false),
                                server(2, 100, alertLayer, 650, 146, 410, 352)]
        check(excluded(content(1), appleScriptAlert), "AppleScript alert is excluded")

        // Finder creates the content window a few ms before the companion. It must be
        // excluded even when only the content window is visible yet.
        let finderAtCreation = [server(3, 100, alertLayer, 725, 212, 260, 234, false)]
        check(excluded(content(3), finderAtCreation), "Finder confirmation is excluded at creation")

        // The resting Finder surface has its 410x384 companion.
        let finderAtRest = finderAtCreation + [server(4, 100, alertLayer, 650, 137, 410, 384)]
        check(excluded(content(3), finderAtRest), "Finder confirmation is excluded at rest")

        // Log Out confirmation from loginwindow: content 267x266 at 721,202; companion 417x416 at 646,127.
        let logOutAlert = [server(5, 100, screenSaverLayer, 721, 202, 267, 266, false),
                           server(6, 100, screenSaverLayer, 646, 127, 417, 416, parent: 5)]
        check(excluded(content(5), logOutAlert), "Log Out confirmation is excluded")

        // macOS 27 permission prompt shape: content 260x364; companion 410x514.
        check(excluded(content(7), [server(7, 100, alertLayer, 725, 215, 260, 364, false),
                                    server(8, 100, alertLayer, 650, 140, 410, 514)]),
              "system permission prompt shape is excluded")

        // Ordinary app windows are normal (layer 0) windows.
        check(!excluded(content(9, 100, kAXWindowRole, kAXStandardWindowSubrole),
                        [server(9, 100, 0, 0, 287, 486, 234)]),
              "ordinary standard window is not excluded")
        check(!excluded(content(10, 100, kAXWindowRole, kAXDialogSubrole),
                        [server(10, 100, 0, 100, 100, 300, 200)]),
              "layer-0 dialog is not excluded")

        // Parented sheets are not the affected standalone alert surface.
        check(!excluded(content(11, 100, kAXWindowRole, kAXDialogSubrole),
                        [server(11, 100, alertLayer, 725, 221, 260, 202, false, parent: 42),
                         server(12, 100, alertLayer, 650, 146, 410, 352, parent: 11)]),
              "parented sheet is not excluded")

        // A standard window at a system alert layer is not an AX dialog.
        check(!excluded(content(13, 100, kAXWindowRole, kAXStandardWindowSubrole),
                        [server(13, 100, alertLayer, 725, 221, 260, 202, false),
                         server(14, 100, alertLayer, 650, 146, 410, 352)]),
              "standard window at modal layer is not excluded")
        check(!excluded(content(15, 100, kAXWindowRole, kAXStandardWindowSubrole),
                        [server(15, 100, screenSaverLayer, 721, 202, 267, 266, false)]),
              "standard window at screen-saver layer is not excluded")

        // Non-alert layers are not excluded, even for AX dialogs.
        check(!excluded(content(16), [server(16, 100, 24, 0, 0, 1710, 34)]),
              "layer-24 dialog is not excluded")

        // If the window is missing from the WindowServer snapshot, the pure
        // classifier says "not an alert"; the capture path fails closed instead.
        check(!excluded(content(17), [server(18, 100, alertLayer, 725, 221, 260, 202, false)]),
              "missing window in snapshot is not classified as an alert")

        // Companion diagnostics: the companion is a corroborating signature, not a requirement.
        func companion(_ windows: [WindowCaptureExclusionTestable.WindowServerWindow],
                       of wid: CGWindowID) -> CGWindowID? {
            guard let content = windows.first(where: { $0.wid == wid }) else { return nil }
            return WindowCaptureExclusionTestable.alertCompanion(of: content, in: windows)?.wid
        }
        check(companion(appleScriptAlert, of: 1) == 2, "AppleScript companion is found")
        check(companion(finderAtRest, of: 3) == 4, "Finder companion is found")
        check(companion(logOutAlert, of: 5) == 6, "Log Out companion is found")

        // An intermediate animation frame still has a concentric, larger companion.
        let animatedFrame = [server(19, 100, alertLayer, 807, 284, 96, 76, false),
                             server(20, 100, alertLayer, 779, 257, 152, 130)]
        check(companion(animatedFrame, of: 19) == 20, "animated companion is found")

        // Non-concentric, wrong-process, wrong-layer, same-size and smaller siblings are not companions.
        check(companion([server(21, 100, alertLayer, 725, 221, 260, 202, false),
                         server(22, 100, alertLayer, 600, 146, 410, 352)], of: 21) == nil,
              "non-concentric sibling is not a companion")
        check(companion([server(23, 100, alertLayer, 725, 221, 260, 202, false),
                         server(24, 200, alertLayer, 650, 146, 410, 352)], of: 23) == nil,
              "other-process sibling is not a companion")
        check(companion([server(25, 100, alertLayer, 725, 221, 260, 202, false),
                         server(26, 100, 0, 650, 146, 410, 352)], of: 25) == nil,
              "other-layer sibling is not a companion")
        check(companion([server(27, 100, alertLayer, 725, 221, 260, 202, false),
                         server(28, 100, alertLayer, 725, 221, 260, 202)], of: 27) == nil,
              "same-sized helper is not a companion")
        check(companion([server(29, 100, alertLayer, 725, 221, 260, 202, false),
                         server(30, 100, alertLayer, 750, 246, 210, 152)], of: 29) == nil,
              "smaller sibling is not a companion")

        if failures > 0 {
            print("\(failures) classifier test(s) failed")
            exit(1)
        }
        print("all classifier tests passed")
    }
}
