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
    private static var repositionTimer: Timer?

    private struct PressedDockIcon {
        let button: Int64
        let bundleIdentifier: String
        let pid: pid_t
        let icon: AXUIElement
    }
    private static var pressedDockIcon: PressedDockIcon?

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
        let eventMask = [CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .otherMouseDown, .otherMouseUp].reduce(CGEventMask(0)) { $0 | (1 << $1.rawValue) }
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
                return Unmanaged.passUnretained(event)
            case .tapDisabledByTimeout, .tapDisabledByUserInput:
                if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
                return Unmanaged.passUnretained(event)
            case .leftMouseDown, .leftMouseUp, .otherMouseDown, .otherMouseUp:
                return handleDockClick(type, event) ? nil : Unmanaged.passUnretained(event)
            default:
                return Unmanaged.passUnretained(event)
        }
    }

    /// Returns true when the click was handled by a DockAltTab mode and must be swallowed (to
    /// avoid the native Dock action and, in particular, an unwanted Space switch).
    private static func handleDockClick(_ type: CGEventType, _ event: CGEvent) -> Bool {
        guard DockAltTabPreviewMode.current.interceptsDockClicks else { return false }
        guard event.flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty else { return false }
        let button: Int64
        let isDown: Bool
        switch type {
            case .leftMouseDown: button = 0; isDown = true
            case .leftMouseUp: button = 0; isDown = false
            case .otherMouseDown: button = 2; isDown = true
            case .otherMouseUp: button = 2; isDown = false
            default: return false
        }
        if isDown {
            guard let element = elementAtPoint(normalizePointForDockGap(event.location)), (try? element.pid()) == dockPid else { return false }
            let iconElement = dockIconElement(element)
            // the Dock's background/bottom gap has no icon: fall back to the icon we were hovering
            let icon = iconElement ?? hoveredIcon
            let bid = iconElement.flatMap { appBundleIdentifier(forDockIcon: $0) } ?? (dockItemSubrole(element) == nil ? hoveredAppBid : nil)
            guard let icon, let bid,
                  let app = NSRunningApplication.runningApplications(withBundleIdentifier: bid).first,
                  app.activationPolicy == .regular,
                  DockAltTabWindowStats(pid: app.processIdentifier).all > 0 else { return false }
            pressedDockIcon = PressedDockIcon(button: button, bundleIdentifier: bid, pid: app.processIdentifier, icon: icon)
            return true
        }
        guard let pressed = pressedDockIcon, pressed.button == button else { return false }
        pressedDockIcon = nil
        performDockClick(pressed, button: button)
        return true
    }

    private static func performDockClick(_ pressed: PressedDockIcon, button: Int64) {
        guard let app = NSRunningApplication(processIdentifier: pressed.pid) else { return }
        let stats = DockAltTabWindowStats(pid: pressed.pid)
        // a click on a non-frontmost icon just brings that app forward
        if !app.isActive {
            hidePreview()
            activateWithoutSpaceSwitch(app)
            return
        }
        if DockAltTabPreviewMode.current == .windows {
            hidePreview()
            app.hide()
            return
        }
        // Ubuntu: left click with 2+ windows, or middle click with 1+, toggles the preview
        if button == 2 {
            if stats.all >= 1 { togglePreview(app, pressed.icon) }
        } else if stats.all >= 2 {
            togglePreview(app, pressed.icon)
        } else {
            hidePreview()
            app.hide()
        }
    }

    private static func togglePreview(_ app: NSRunningApplication, _ icon: AXUIElement) {
        if isPreviewShowing, DockAltTabApp?.processIdentifier == app.processIdentifier {
            hidePreview()
            return
        }
        guard let bid = app.bundleIdentifier,
              let attrs = try? icon.attributes([kAXPositionAttribute, kAXSizeAttribute]),
              let position = attrs.position, let size = attrs.size else { return }
        previewTarget = nil
        cancelThumbnail()
        refreshDockState()
        let (x, y) = previewPosition(position, size)
        isPreviewShowing = DockAltTabShowAppPreviews(tarBID: bid, x: x, y: y, dockPos: dockPos)
        if isPreviewShowing { ensureDockShowing(); trackPreviewPosition(icon) } else { restoreDockAutohide() }
    }

    /// Activating a hidden app directly can trigger a Space switch. Unhiding first and only
    /// activating once it is visible avoids the swoosh (same trick the original DockAltTab used).
    private static func activateWithoutSpaceSwitch(_ app: NSRunningApplication) {
        guard app.isHidden else { activateNow(app); return }
        app.unhide()
        waitUntilVisibleThenActivate(app, attempts: 0)
    }

    private static func waitUntilVisibleThenActivate(_ app: NSRunningApplication, attempts: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(20)) {
            if app.isHidden && attempts < 50 {
                waitUntilVisibleThenActivate(app, attempts: attempts + 1)
            } else {
                activateNow(app)
            }
        }
    }

    private static func activateNow(_ app: NSRunningApplication) {
        if #available(macOS 14.0, *) {
            _ = app.activate(from: NSWorkspace.shared.frontmostApplication ?? NSRunningApplication.current, options: [.activateIgnoringOtherApps])
        } else {
            _ = app.activate(options: [.activateIgnoringOtherApps])
        }
    }

    private static func processPendingMouse() {
        guard let location = pendingMouseLocation else { return }
        pendingMouseLocation = nil
        handleMouseMoved(location)
    }

    private static func handleMouseMoved(_ location: CGPoint) {
        guard let element = elementAtPoint(normalizePointForDockGap(location)), let pid = try? element.pid() else { pointerLeft(); return }
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
              let bid = appBundleIdentifier(forDockIcon: icon) else {
            // Real Dock items (spacers, folders/stacks, Trash) dismiss the preview. The Dock's
            // background/bottom gap has no dock-item subrole, so keep the current preview there.
            if dockItemSubrole(element) != nil {
                cancelShow()
                hoveredAppBid = nil
                hoveredIcon = nil
                hidePreview()
            }
            return
        }
        guard bid != hoveredAppBid else { return }
        hoveredAppBid = bid
        hoveredIcon = icon
        cancelShow()
        // Ubuntu mode has no hover previews (previews are toggled by click instead)
        guard DockAltTabPreviewMode.current.showsPreviewOnHover else { return }
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
        if isPreviewShowing { ensureDockShowing(); trackPreviewPosition(icon) } else { restoreDockAutohide() }
    }

    /// The Dock magnifies the hovered icon, and shrinks it back once the pointer moves off it. Follow
    /// the icon's AX frame while the preview is up, but only reposition once it has settled; otherwise
    /// the panel would jitter along with every frame of the magnification animation.
    private static func trackPreviewPosition(_ icon: AXUIElement) {
        guard DockAltTabPreferences.repositionPreviewAfterMagnification else { return }
        repositionTimer?.invalidate()
        var candidateX: Int?
        var candidateY: Int?
        var stableTicks = 0
        repositionTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { timer in
            guard isPreviewShowing else { timer.invalidate(); repositionTimer = nil; return }
            guard let attrs = try? icon.attributes([kAXPositionAttribute, kAXSizeAttribute]),
                  let position = attrs.position, let size = attrs.size else { return }
            let (x, y) = previewPosition(position, size)
            if candidateX == x, candidateY == y {
                stableTicks += 1
            } else {
                candidateX = x
                candidateY = y
                stableTicks = 0
                return
            }
            guard stableTicks >= 2, DockAltTabFORCEDX != x || DockAltTabFORCEDY != y else { return }
            DockAltTabFORCEDX = x
            DockAltTabFORCEDY = y
            stableTicks = 0
            if let panel = TilesPanel.shared, panel.isVisible, DockAltTabMode { panel.screen?.repositionPanel(panel) }
        }
    }

    private static func hidePreview() {
        hideWork = nil
        repositionTimer?.invalidate()
        repositionTimer = nil
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

    /// `Bundle(url:)` raises for non-file URLs, so only use it on file URLs (some dock items
    /// expose schemes like `x-apple-*` and would otherwise crash).
    private static func appBundleIdentifier(forDockIcon icon: AXUIElement) -> String? {
        guard let url = (try? icon.attributes([kAXURLAttribute]))?.url, url.isFileURL else { return nil }
        return Bundle(url: url)?.bundleIdentifier
    }

    /// The subrole of the Dock item at (or above) an element, e.g. `AXApplicationDockItem`.
    /// The Dock's background/gap has no such subrole, which is how we tell it apart from spacers/folders.
    private static func dockItemSubrole(_ element: AXUIElement) -> String? {
        var current: AXUIElement? = element
        var depth = 0
        while let el = current, depth < 6 {
            if let subrole = (try? el.attributes([kAXSubroleAttribute]))?.subrole, subrole.contains("DockItem") { return subrole }
            current = (try? el.attributes([kAXParentAttribute]))?.parent
            depth += 1
        }
        return nil
    }

    /// AX hit-testing returns nothing in the last few pixels at the screen edge, even though the
    /// Dock icons remain clickable there. Nudge the point back inside the Dock (ported from the
    /// original DockAltTab).
    private static func normalizePointForDockGap(_ point: CGPoint) -> CGPoint {
        guard let primary = NSScreen.screens.first else { return point }
        let cocoaPoint = CGPoint(x: point.x, y: primary.frame.height - point.y)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(cocoaPoint) }) else { return point }
        let topBasedTop = primary.frame.height - (screen.frame.origin.y + screen.frame.height)
        switch dockPos {
            case "bottom":
                let cutoff = topBasedTop + screen.frame.height - 5.1
                return CGPoint(x: point.x, y: point.y >= cutoff ? cutoff : point.y)
            case "left":
                let cutoff = screen.frame.origin.x + 14.1
                return CGPoint(x: point.x <= cutoff ? cutoff : point.x, y: point.y)
            case "right":
                let cutoff = screen.frame.origin.x + screen.frame.width - 14.1
                return CGPoint(x: point.x >= cutoff ? cutoff : point.x, y: point.y)
            default:
                return point
        }
    }

    /// Compute where the preview panel should be anchored, relative to the hovered dock icon.
    /// AX reports positions from the top-left of the primary screen, while NSWindow frames use
    /// Cocoa coordinates (origin bottom-left), so Y has to be flipped here. With dock magnification,
    /// the icon grows away from the screen edge while its far edge stays anchored, so we add the
    /// magnification size on top of the icon's anchored edge rather than relying on the AX frame.
    private static func previewPosition(_ position: CGPoint, _ size: CGSize) -> (Int, Int) {
        let screenHeight = NSScreen.screens.first?.frame.height ?? 0
        let gutter = CGFloat(DockAltTabPreferences.previewGutter)
        let magnified = CGFloat(dockMagnificationSize)
        var x = position.x
        var y = position.y
        let width = size.width
        let height = size.height
        if dockMagnification {
            if dockPos == "bottom" {
                x += width / 2
                y = screenHeight - (position.y + height) + magnified + gutter
            } else {
                y = screenHeight - (position.y + height / 2)
                x = dockPos == "right" ? position.x + width - magnified - gutter : position.x + magnified + gutter
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
