import Foundation
import Cocoa

var DockAltTabThumbnailPreview: Bool? = false //cached value, to restore after we force preview
var DockAltTabWaitForWindow: CGWindowID = 0
func DockAltTabThumbnailPreviewRequestHD(window: Window) {
    guard let cgWindowId = window.cgWindowId else { return }
    DockAltTabWaitForWindow = cgWindowId
    DispatchQueue.main.async {
        if DockAltTabWaitForWindow != window.cgWindowId { return } // WaitForWindow changed, don't get this thumbnail then
        Windows.refreshThumbnailsAsync([window], .refreshUiAfterExternalEvent)
    }

}
class thumbnailPreviewScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        DockAltTabShowThumbnailPreview()
        return self
    }
}
