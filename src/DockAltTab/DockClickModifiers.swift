import Cocoa

/// What a press on a Dock icon does, decided from the button and the modifiers held.
enum DockClickAction {
    case plain
    case cycleWindows
    case newWindow
    case contextMenu
}

/// Modifier-click overrides on Dock icons, ported from Dock Exposé's "Dock Clicks" section.
extension DockAltTab {
    /// Only the named modifier may be held; e.g. ⇧⌘-click is left to the Dock. A disabled modifier
    /// passes through too, so the Dock's own behaviour (and any Space switch) is unchanged.
    static func dockClickAction(button: Int64, flags: CGEventFlags) -> DockClickAction? {
        let modifiers = flags.intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
        guard button == 0 else { return modifiers.isEmpty ? .plain : nil }
        if modifiers.isEmpty { return .plain }
        if modifiers == .maskCommand, DockAltTabPreferences.cmdClickCyclesWindows { return .cycleWindows }
        if modifiers == .maskAlternate, DockAltTabPreferences.optionClickShowsContextMenu { return .contextMenu }
        if modifiers == .maskShift, DockAltTabPreferences.shiftClickOpensNewWindow { return .newWindow }
        return nil
    }

    /// ⌘-click: raise the app's next window, in creation order, skipping minimized windows (like the
    /// Dock's own ⌘-click, but without its Space switch). Creation order never changes, whereas the
    /// focus order does as windows are raised, which would make a focus-relative cycle skip windows.
    static func cycleAppWindows(pid: pid_t) {
        let windows = Windows.list.filter {
            $0.application.pid == pid && !$0.isMinimized && !$0.isWindowlessApp && $0.cgWindowId != nil &&
                $0.spaceIds.contains(where: { Spaces.visibleSpaces.contains($0) })
        }.sorted { $0.creationOrder < $1.creationOrder }
        guard !windows.isEmpty else { return }
        let focusedWid = Applications.list.first { $0.pid == pid }?.focusedWindow?.cgWindowId
        let focusedIndex = windows.firstIndex { $0.cgWindowId == focusedWid }
        windows[focusedIndex.map { ($0 + 1) % windows.count } ?? (windows.count > 1 ? 1 : 0)].focus()
    }

    /// ⇧-click: ask the app for a new window. Addressing the process directly (Cmd-N to its pid) works
    /// even when the app cannot become frontmost. VLC opens its new window as a new app instance.
    static func openNewWindow(pid: pid_t) {
        guard let app = NSRunningApplication(processIdentifier: pid) else { return }
        activateWithoutSpaceSwitch(app)
        if app.bundleIdentifier == "org.videolan.vlc", let url = app.bundleURL {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration)
            return
        }
        // give the app a moment to come forward: Cmd-N should reach it, not whatever was frontmost
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) { postCommandN(pid: pid) }
    }

    /// ⌥-click: send a right-click instead of hiding the app, so the Dock shows its context menu.
    static func postRightClick(at point: CGPoint) {
        let down = CGEvent(mouseEventSource: nil, mouseType: .rightMouseDown, mouseCursorPosition: point, mouseButton: .right)
        let up = CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: point, mouseButton: .right)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    private static func postCommandN(pid: pid_t) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 45, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 45, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.postToPid(pid)
        up?.postToPid(pid)
    }
}
