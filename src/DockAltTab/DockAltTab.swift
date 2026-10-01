import Cocoa
import ApplicationServices

// private Dock APIs, same ones the original DockAltTab used (Boolean == UInt8)
@_silgen_name("CoreDockGetAutoHideEnabled")
private func CoreDockGetAutoHideEnabled() -> UInt8
@_silgen_name("CoreDockSetAutoHideEnabled")
private func CoreDockSetAutoHideEnabled(_ flag: UInt8)

/// Standalone dock-icon-hover previews.
///
/// This replaces the old two-app setup: instead of an AppleScript event tap in a separate
/// DockAltTab process talking to AltTab, this observer lives inside AltTab and drives the
/// existing window/panel machinery directly.
class DockAltTab {
    static var isRunning = false
    static var isPreviewShowing = false

    private static var eventTap: CFMachPort?
    private static let systemWide = AXUIElementCreateSystemWide()
    private static var dockPid: pid_t = 0
    private static var dockPos = "bottom"
    private static var dockAutohide = false
    private static var dockMagnification = false
    private static var dockMagnificationSize = 16

    private static var hoveredAppBid: String?
    private static var hoveredIcon: AXUIElement?
    private static var previewTarget: AXUIElement?
    private static var showWork: DispatchWorkItem?
    private static var hideWork: DispatchWorkItem?
    private static var thumbnailWork: DispatchWorkItem?
    private static var pendingMouseLocation: CGPoint?
    private static var mouseSamplingTimer: Timer?

    static func initialize() {
        guard !isRunning else { return }
        isRunning = true
        refreshDockState()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.dock" else { return }
            refreshDockState()
        }
        ensureShowHiddenDockPref()
        let eventMask = [CGEventType.mouseMoved].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: handleEvent,
            userInfo: nil)
        guard let eventTap else {
            Logger.warning { "dockAltTab: could not create event tap" }
            return
        }
        let runLoopSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        // all we do is read NSEvent/AX state, so main-thread is where this belongs
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        // AX lookups are expensive; sample the cursor on a timer rather than inside the tap callback,
        // otherwise macOS disables the tap for being too slow
        mouseSamplingTimer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { _ in processPendingMouse() }
        mouseSamplingTimer?.tolerance = 0.01
        Logger.info { "Finished initializing DockAltTab" }
    }

    static func refreshDockState() {
        dockPid = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first?.processIdentifier ?? 0
        dockPos = (dockPref("orientation") as? String) ?? dockPos
        dockAutohide = (dockPref("autohide") as? NSNumber)?.boolValue ?? dockAutohide
        dockMagnification = (dockPref("magnification") as? NSNumber)?.boolValue ?? dockMagnification
        dockMagnificationSize = (dockPref("largesize") as? NSNumber)?.intValue ?? dockMagnificationSize
    }

    /// Called by the cursor event handlers when a click passes through to the Dock.
    static func dismissPreview() { hidePreview() }

    private static let handleEvent: CGEventTapCallBack = { _, type, event, _ in
        switch type {
            case .mouseMoved:
                pendingMouseLocation = event.location
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            default:
                break
        }
        return Unmanaged.passUnretained(event)
    }

    private static func processPendingMouse() {
        guard let location = pendingMouseLocation else { return }
        pendingMouseLocation = nil
        handleMouseMoved(location)
    }

    private static func handleMouseMoved(_ location: CGPoint) {
        guard let element = elementAtPoint(location), let pid = try? element.pid() else { pointerLeft(); return }
        if pid == dockPid {
            handleDockHover(element)
        } else if pid == ProcessInfo.processInfo.processIdentifier {
            handlePreviewHover(element)
        } else if NSRunningApplication(processIdentifier: pid)?.bundleIdentifier == "com.apple.dock" {
            // the Dock was restarted; pick up its new pid and keep going
            refreshDockState()
            handleDockHover(element)
        } else {
            pointerLeft()
        }
    }

    /// The original DockAltTab enabled the Dock's "showhidden" pref and restarted the Dock.
    private static func ensureShowHiddenDockPref() {
        guard (dockPref("showhidden") as? NSNumber)?.boolValue != true else { return }
        CFPreferencesSetAppValue("showhidden" as CFString, kCFBooleanTrue, "com.apple.dock" as CFString)
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        Logger.info { "dockAltTab: enabling Dock 'showhidden', restarting the Dock" }
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }

    private static func handleDockHover(_ element: AXUIElement) {
        cancelHide()
        cancelThumbnail()
        guard let icon = dockIconElement(element),
              let url = (try? icon.attributes([kAXURLAttribute]))?.url,
              let bid = Bundle(url: url)?.bundleIdentifier else {
            // spacers, folders/stacks, Trash, etc. have no app bundle: dismiss any preview
            cancelShow()
            hoveredAppBid = nil
            hoveredIcon = nil
            hidePreview()
            return
        }
        guard bid != hoveredAppBid else { return }
        hoveredAppBid = bid
        hoveredIcon = icon
        cancelShow()
        // once a preview is open, hovering another app should switch to it immediately
        let delay = (TilesPanel.shared?.isVisible ?? false) ? 0 : DockAltTabPreferences.previewDelayMs
        let work = DispatchWorkItem { showPreviews(bid: bid, icon: icon) }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: work)
    }

    private static func handlePreviewHover(_ element: AXUIElement) {
        cancelHide()
        guard DockAltTabMode else { return }
        if DockAltTabPreferences.keepDockShowing && dockAutohide && CoreDockGetAutoHideEnabled() != 0 {
            CoreDockSetAutoHideEnabled(0)
        }
        guard DockAltTabPreferences.thumbnailPreviewsEnabled else { return }
        guard let attrs = try? element.attributes([kAXRoleAttribute, kAXSubroleAttribute, kAXChildrenAttribute]),
              let role = attrs.role else { return }
        // clicking/leaving through the float preview panel itself should hide the previews
        if role == "AXWindow" && attrs.subrole == "AXUnknown" && (attrs.children?.isEmpty ?? true) {
            hidePreview()
            return
        }
        guard ["AXUnknown", "AXScrollArea", "AXStaticText", "AXButton"].contains(role) else { return }
        if let target = previewTarget, CFEqual(target, element) { return }
        previewTarget = element
        cancelThumbnail()
        // once the preview panel is open, hovering another thumbnail should update it immediately
        let delay = PreviewPanel.shared.isVisible ? 0 : DockAltTabPreferences.thumbnailPreviewDelayMs
        let work = DispatchWorkItem { DockAltTabShowThumbnailPreview() }
        thumbnailWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: work)
    }

    private static func pointerLeft() {
        cancelShow()
        hoveredAppBid = nil
        hoveredIcon = nil
        guard DockAltTabMode else { isPreviewShowing = false; return }
        cancelHide()
        let work = DispatchWorkItem { hidePreview() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(DockAltTabPreferences.previewHideDelayMs), execute: work)
    }

    private static func showPreviews(bid: String, icon: AXUIElement) {
        showWork = nil
        guard hoveredAppBid == bid else { return }
        guard let attrs = try? icon.attributes([kAXPositionAttribute, kAXSizeAttribute]),
              let position = attrs.position, let size = attrs.size else { return }
        refreshDockState()
        previewTarget = nil
        cancelThumbnail()
        let (x, y) = previewPosition(position, size)
        isPreviewShowing = DockAltTabShowAppPreviews(tarBID: bid, x: x, y: y, dockPos: dockPos)
        if isPreviewShowing { ensureDockShowing() } else { restoreDockAutohide() }
    }

    private static func hidePreview() {
        hideWork = nil
        cancelThumbnail()
        previewTarget = nil
        guard DockAltTabMode else { isPreviewShowing = false; return }
        isPreviewShowing = false
        DockAltTabHide()
        restoreDockAutohide()
    }

    private static func ensureDockShowing() {
        guard DockAltTabPreferences.keepDockShowing, dockAutohide else { return }
        CoreDockSetAutoHideEnabled(0)
    }

    private static func restoreDockAutohide() {
        guard dockAutohide, CoreDockGetAutoHideEnabled() == 0 else { return }
        CoreDockSetAutoHideEnabled(1)
    }

    // MARK: - dock/AX helpers

    private static func dockPref(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }

    private static func elementAtPoint(_ location: CGPoint) -> AXUIElement? {
        var element: AXUIElement?
        let result = AXUIElementCopyElementAtPosition(systemWide, Float(location.x), Float(location.y), &element)
        return result == .success ? element : nil
    }

    /// The AX hit-test can return a dock icon child; walk up until we find the tile that carries the app URL.
    private static func dockIconElement(_ element: AXUIElement) -> AXUIElement? {
        var current: AXUIElement? = element
        var depth = 0
        while let el = current, depth < 6 {
            if (try? el.attributes([kAXURLAttribute]))?.url != nil { return el }
            current = (try? el.attributes([kAXParentAttribute]))?.parent
            depth += 1
        }
        return nil
    }

    /// Compute where the preview panel should be anchored, relative to the hovered dock icon.
    /// AX reports positions from the top-left of the primary screen, while NSWindow frames use
    /// Cocoa coordinates (origin bottom-left), so Y has to be flipped here.
    private static func previewPosition(_ position: CGPoint, _ size: CGSize) -> (Int, Int) {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let gutter = CGFloat(DockAltTabPreferences.previewGutter)
        var x = position.x
        var y = position.y
        let width = size.width
        var height = size.height
        if dockMagnification {
            if dockPos == "bottom" {
                height = CGFloat(dockMagnificationSize)
                x += width / 2
                let ratio = CGFloat(dockMagnificationSize) / 128
                y = height + 2.7 / (ratio * ratio) + gutter
            } else {
                height = CGFloat(dockMagnificationSize)
                y = screenHeight - (position.y + size.height / 2)
                x = dockPos == "right" ? position.x - gutter : position.x + size.width + gutter
            }
        } else if dockPos == "bottom" {
            x += width / 2
            y = screenHeight - position.y + gutter
        } else {
            y = screenHeight - (position.y + height / 2)
            x = dockPos == "right" ? position.x - gutter : position.x + width + gutter
        }
        return (Int(x), Int(y))
    }

    private static func cancelShow() {
        showWork?.cancel()
        showWork = nil
    }
    private static func cancelHide() {
        hideWork?.cancel()
        hideWork = nil
    }
    private static func cancelThumbnail() {
        thumbnailWork?.cancel()
        thumbnailWork = nil
    }
}
