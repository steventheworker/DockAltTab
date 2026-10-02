import Cocoa

/// The preview plumbing that the original DockAltTab used to trigger through AppleScript.
/// We call these directly now that DockAltTab and AltTab live in the same process.

/// Show window previews (the AltTab panel) for a specific app.
/// Passing x/y forces DockAltTab positioning mode (panel anchored to the hovered dock icon).
/// Returns true if a preview ended up being shown.
@discardableResult
func DockAltTabShowAppPreviews(tarBID: String, x: Int?, y: Int?, dockPos: String?) -> Bool {
    DockAltTabResetCachedThumbnailPreviewSetting()
    if tarBID.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
        Logger.warning { "dockAltTab: empty app bundle identifier" }
        DockAltTabHide()
        return false
    }
    let appInstances = NSRunningApplication.runningApplications(withBundleIdentifier: tarBID)
    guard let tarApp = appInstances.first else {
        Logger.debug { "dockAltTab: '\(tarBID)' is not running" }
        DockAltTabHide()
        return false
    }
    if x != nil || y != nil {
        startDockAltTabMode(app: tarApp)
    } else {
        DockAltTabReset()
    }
    DockAltTabFORCEDX = x ?? (Int(NSEvent.mouseLocation.x) - 40)
    DockAltTabFORCEDY = y ?? (Int(NSEvent.mouseLocation.y) + 40)
    DockAltTabDockPos = dockPos ?? "bottom"
    App.appIsBeingUsed = true
    NSScreen.updatePreferred()
    if App.isVeryFirstSummon {
        Windows.sortByLevel()
        App.isVeryFirstSummon = false
    }
    App.isFirstSummon = false
    App.shortcutIndex = 2 // Shortcut 3 = index 2 = DockAltTab
    guard Windows.updatesBeforeShowing() else {
        App.hideUi()
        DockAltTabReset()
        return false
    }
    guard Windows.list.contains(where: { $0.shouldShowTheUser }) else {
        App.hideUi()
        DockAltTabReset()
        return false
    }
    Windows.setInitialSelectedAndHoveredWindowIndex()
    if Preferences.windowDisplayDelay == DispatchTimeInterval.milliseconds(0) {
        App.buildUiAndShowPanel()
    } else {
        App.delayedDisplayScheduled += 1
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Preferences.windowDisplayDelay) { () -> () in
            if App.delayedDisplayScheduled == 1 {
                App.buildUiAndShowPanel()
            }
            App.delayedDisplayScheduled -= 1
        }
    }
    return true
}

/// Force the (large) preview of the currently selected window to show, fetching a HD thumbnail first.
func DockAltTabShowThumbnailPreview() {
    guard App.appIsBeingUsed, let selectedWin = Windows.selectedWindow(), selectedWin.cgWindowId != nil else { return }
    DockAltTabThumbnailPreviewRequestHD(window: selectedWin)
    Windows.previewSelectedWindowIfNeeded()
}

/// Hide the AltTab UI and leave DockAltTab mode.
func DockAltTabHide() {
    App.hideUi()
    DockAltTabReset()
}

/// Window stats for a single app, computed from AltTab's own window model (no CGWindowList needed).
func DockAltTabWindowStats(pid: pid_t) -> (all: Int, current: Int, minimizedCurrent: Int) {
    var all = 0
    var current = 0
    var minimizedCurrent = 0
    for window in Windows.list {
        guard window.application.pid == pid, !window.isWindowlessApp else { continue }
        all += 1
        guard window.spaceIds.contains(where: { Spaces.visibleSpaces.contains($0) }) else { continue }
        current += 1
        if window.isMinimized { minimizedCurrent += 1 }
    }
    return (all, current, minimizedCurrent)
}
