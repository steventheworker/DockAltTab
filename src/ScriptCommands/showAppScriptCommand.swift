var DockAltTabFORCEDX = 0
var DockAltTabFORCEDY = 0
var DockAltTabDockPos = ""
var DockAltTabApp: NSRunningApplication? = nil
var DockAltTabRepositionTimer: Timer? = nil

func DockAltTabRadiusFix() {
    if (Preferences.theme != .macOs) {return}
    let num = 22.0
    TilesView.contentView.layer?.cornerRadius = CGFloat(num)
    TilesView.contentView.updateRoundedCorners(num)
    TilesView.scrollView.layer?.cornerRadius = CGFloat(num)
}
func startDockAltTabMode(app: NSRunningApplication) {
    DockAltTabMode = true
    DockAltTabRadiusFix()
    DockAltTabApp = app
}
func DockAltTabResetCachedThumbnailPreviewSetting() {
    DockAltTabWaitForWindow = 0
}
func DockAltTabReset() { //called on HideScriptCommand.swift, App.showUiOrCycleSelection (key shortcut)
    DockAltTabMode = false
    DockAltTabRadiusFix()
    DockAltTabFORCEDX = 0
    DockAltTabFORCEDY = 0
    DockAltTabResetCachedThumbnailPreviewSetting()
}

// used by DockAltTab - show window previews for a specific app (1st window highlighted), ignoring blacklist
// the implementation lives in src/DockAltTab/DockAltTabPreview.swift; the script command is kept for automation
import Foundation
import Cocoa

class showAppScriptCommand: NSScriptCommand {
	override func performDefaultImplementation() -> Any? {
        guard let tarBID = self.evaluatedArguments!["appBID"] as? String else { return self }
        DockAltTabShowAppPreviews(
            tarBID: tarBID,
            x: self.evaluatedArguments!["x"] as? Int,
            y: self.evaluatedArguments!["y"] as? Int,
            dockPos: self.evaluatedArguments!["dockPos"] as? String)
        return self
	}
}
