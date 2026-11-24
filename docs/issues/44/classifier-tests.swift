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
        let alertLayer = Int(WindowCaptureExclusionTestable.modalPanelLevel)

        func content(_ wid: CGWindowID, _ pid: pid_t = 100, _ role: String? = kAXWindowRole,
                     _ subrole: String? = kAXDialogSubrole, _ parentWid: CGWindowID = 0)
            -> WindowCaptureExclusionTestable.CapturableWindow {
            WindowCaptureExclusionTestable.CapturableWindow(wid: wid, pid: pid, parentWid: parentWid,
                                                            axRole: role, axSubrole: subrole)
        }
        func server(_ wid: CGWindowID, _ pid: pid_t = 100, _ layer: Int = 8, _ x: CGFloat, _ y: CGFloat,
                    _ width: CGFloat, _ height: CGFloat, _ onscreen: Bool = true)
            -> WindowCaptureExclusionTestable.WindowServerWindow {
            WindowCaptureExclusionTestable.WindowServerWindow(wid: wid, pid: pid, layer: layer,
                                                              bounds: CGRect(x: x, y: y, width: width, height: height),
                                                              onscreen: onscreen)
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

        // macOS 27 permission prompt shape: content 260x364; companion 410x514.
        check(excluded(content(5), [server(5, 100, alertLayer, 725, 215, 260, 364, false),
                                    server(6, 100, alertLayer, 650, 140, 410, 514)]),
              "system permission prompt shape is excluded")

        // Finder Connect to Server and ordinary app windows are normal (layer 0) windows.
        check(!excluded(content(7, 100, kAXWindowRole, kAXStandardWindowSubrole),
                        [server(7, 100, 0, 0, 287, 486, 234)]),
              "Connect to Server is not excluded")
        check(!excluded(content(8, 100, kAXWindowRole, kAXDialogSubrole),
                        [server(8, 100, 0, 100, 100, 300, 200)]),
              "layer-0 dialog is not excluded")

        // Parented sheets are not the affected standalone alert surface.
        check(!excluded(content(9, 100, kAXWindowRole, kAXDialogSubrole, 42),
                        [server(9, 100, alertLayer, 725, 221, 260, 202, false),
                         server(10, 100, alertLayer, 650, 146, 410, 352)]),
              "parented sheet is not excluded")

        // A standard window at the modal layer is not an AX dialog.
        check(!excluded(content(11, 100, kAXWindowRole, kAXStandardWindowSubrole),
                        [server(11, 100, alertLayer, 725, 221, 260, 202, false),
                         server(12, 100, alertLayer, 650, 146, 410, 352)]),
              "standard window at modal layer is not excluded")

        // Non-modal AX dialogs (e.g. menu-bar helper windows) are not excluded.
        check(!excluded(content(13), [server(13, 100, 24, 0, 0, 1710, 34)]),
              "layer-24 dialog is not excluded")

        // If the window is missing from the WindowServer snapshot, fail open.
        check(!excluded(content(14), [server(15, 100, alertLayer, 725, 221, 260, 202, false)]),
              "missing window in snapshot is not excluded")

        // Companion diagnostics: the companion is a corroborating signature, not a requirement.
        func companion(_ windows: [WindowCaptureExclusionTestable.WindowServerWindow],
                       of wid: CGWindowID) -> CGWindowID? {
            guard let content = windows.first(where: { $0.wid == wid }) else { return nil }
            return WindowCaptureExclusionTestable.alertCompanion(of: content, in: windows)?.wid
        }
        check(companion(appleScriptAlert, of: 1) == 2, "AppleScript companion is found")
        check(companion(finderAtRest, of: 3) == 4, "Finder companion is found")

        // An intermediate animation frame still has a concentric, larger companion.
        let animatedFrame = [server(16, 100, alertLayer, 807, 284, 96, 76, false),
                             server(17, 100, alertLayer, 779, 257, 152, 130)]
        check(companion(animatedFrame, of: 16) == 17, "animated companion is found")

        // Non-concentric, wrong-process, wrong-layer, same-size and smaller siblings are not companions.
        check(companion([server(18, 100, alertLayer, 725, 221, 260, 202, false),
                         server(19, 100, alertLayer, 600, 146, 410, 352)], of: 18) == nil,
              "non-concentric sibling is not a companion")
        check(companion([server(20, 100, alertLayer, 725, 221, 260, 202, false),
                         server(21, 200, alertLayer, 650, 146, 410, 352)], of: 20) == nil,
              "other-process sibling is not a companion")
        check(companion([server(22, 100, alertLayer, 725, 221, 260, 202, false),
                         server(23, 100, 0, 650, 146, 410, 352)], of: 22) == nil,
              "other-layer sibling is not a companion")
        check(companion([server(24, 100, alertLayer, 725, 221, 260, 202, false),
                         server(25, 100, alertLayer, 725, 221, 260, 202)], of: 24) == nil,
              "same-sized helper is not a companion")
        check(companion([server(26, 100, alertLayer, 725, 221, 260, 202, false),
                         server(27, 100, alertLayer, 750, 246, 210, 152)], of: 26) == nil,
              "smaller sibling is not a companion")

        if failures > 0 {
            print("\(failures) classifier test(s) failed")
            exit(1)
        }
        print("all classifier tests passed")
    }
}
