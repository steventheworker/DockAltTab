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

    static func initialize() {
        guard !isRunning else { return }
        isRunning = true
        refreshDockState()
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.apple.dock" else { return }
            refreshDockState()
        }
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
        if type == .mouseMoved { handleMouseMoved(event.location) }
        return Unmanaged.passUnretained(event)
    }

    private static func handleMouseMoved(_ location: CGPoint) {
        guard let element = elementAtPoint(location) else { pointerLeft(); return }
        let pid = try? element.pid()
        if pid == dockPid {
            handleDockHover(element)
        } else if pid == ProcessInfo.processInfo.processIdentifier {
            handlePreviewHover(element)
        } else {
            pointerLeft()
        }
    }

    private static func handleDockHover(_ element: AXUIElement) {
        cancelHide()
        cancelThumbnail()
        guard let icon = dockIconElement(element),
              let url = (try? icon.attributes([kAXURLAttribute]))?.url,
              let bid = Bundle(url: url)?.bundleIdentifier else { return }
        guard bid != hoveredAppBid else { return }
        hoveredAppBid = bid
        hoveredIcon = icon
        cancelShow()
        let work = DispatchWorkItem { showPreviews(bid: bid, icon: icon) }
        showWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(DockAltTabPreferences.previewDelayMs), execute: work)
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
        let wasPreviewing = previewTarget != nil
        previewTarget = element
        cancelThumbnail()
        let delay = wasPreviewing ? 0 : DockAltTabPreferences.thumbnailPreviewDelayMs
        let work = DispatchWorkItem { DockAltTabShowThumbnailPreview() }
        thumbnailWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delay), execute: work)
    }

    private static func pointerLeft() {
        cancelShow()
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
        let (x, y) = previewPosition(position, size)
        DockAltTabShowAppPreviews(tarBID: bid, x: x, y: y, dockPos: dockPos)
        isPreviewShowing = true
        ensureDockShowing()
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
    private static func previewPosition(_ position: CGPoint, _ size: CGSize) -> (Int, Int) {
        var x = position.x
        var y = position.y
        var width = size.width
        var height = size.height
        if dockMagnification {
            if dockPos == "bottom" {
                height = CGFloat(dockMagnificationSize)
                x += width / 2
                let ratio = CGFloat(dockMagnificationSize) / 128
                y = height + 2.7 / (ratio * ratio)
            } else {
                width = CGFloat(dockMagnificationSize)
                if dockPos == "right" {
                    x += 35 * (CGFloat(dockMagnificationSize) / 128)
                } else if dockPos == "left" {
                    x = size.width - 17 * (CGFloat(dockMagnificationSize) / 128)
                }
                y -= height / 2
            }
        } else if dockPos == "bottom" {
            x += width / 2
            y -= 12
        } else if dockPos == "left" {
            x += width - 5
            y -= height / 2
        } else if dockPos == "right" {
            x += 12
            y -= height / 2
        }
        let gutter = CGFloat(DockAltTabPreferences.previewGutter)
        if dockPos == "bottom" {
            y += gutter
        } else {
            x += dockPos == "left" ? gutter : -gutter
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
