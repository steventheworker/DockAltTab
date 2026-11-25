import Cocoa

/// Draws the Dock's pressed-icon dim for clicks we swallow: the Dock never sees the press, so it
/// cannot draw its own pressed state. A click-through borderless window just above the Dock's window
/// level, holding a black rounded square over the icon, matches the Dock's look.
class DockPressHighlight {
    static let shared = DockPressHighlight()

    /// Black alpha of the Dock's pressed-icon dim: the Dock multiplies the icon's pixels with black at
    /// ~52% (sampled from a native pressed icon), and an overlay at this alpha reproduces the result.
    private static let dimAlpha: CGFloat = 0.525
    /// macOS 26/27 app icons are rounded squares whose corner radius is ~24% of the icon side.
    private static let cornerRatio: CGFloat = 0.24
    /// The icon is 0.79 of the Dock cell's short side (measured on a 109.7pt Dock).
    private static let iconRatio: CGFloat = 0.79
    private static let minimumIconSide: CGFloat = 2

    private var window: NSWindow?

    /// Dims the icon in the given AX Dock cell (top-left origin, as the event tap and AX report it).
    /// No-op when the cell has no usable frame.
    func show(cell: CGRect) {
        guard let frame = iconDrawFrame(inCell: cell), let mainHeight = NSScreen.screens.first?.frame.height else { return }
        let window = ensureWindow()
        window.contentView?.layer?.cornerRadius = (frame.width * Self.cornerRatio).rounded()
        window.setFrame(NSRect(x: frame.minX.rounded(), y: (mainHeight - frame.maxY).rounded(), width: frame.width, height: frame.height), display: true)
        window.orderFrontRegardless()
    }

    func hide() {
        window?.orderOut(nil)
    }

    /// The AX item frame is the Dock's cell: the icon plus its spacing on the short axis, and the
    /// label/magnification slack on the long axis. A side Dock draws the app name toward the screen
    /// centre, so there the icon hugs the screen edge instead of being centred in the cell.
    private func iconDrawFrame(inCell cell: CGRect) -> CGRect? {
        guard cell.width > 0, cell.height > 0 else { return nil }
        let shortSide = min(cell.width, cell.height)
        let side = (shortSide * Self.iconRatio).rounded()
        guard side >= Self.minimumIconSide else { return nil }
        let y = cell.midY - side / 2
        guard cell.width < cell.height else { return CGRect(x: cell.midX - side / 2, y: y, width: side, height: side) }
        let spacing = (shortSide - side) / 2
        let leftDock = NSScreen.screens.first.map { cell.minX < $0.frame.midX } ?? true
        return CGRect(x: leftDock ? cell.minX + spacing : cell.maxX - spacing - side, y: y, width: side, height: side)
    }

    private func ensureWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.hidesOnDeactivate = false
        window.ignoresMouseEvents = true
        // A window is otherwise bound to the space it was first ordered in; the Dock shows on every space.
        window.collectionBehavior = [.stationary, .ignoresCycle, .fullScreenAuxiliary, .canJoinAllSpaces]
        let dimView = NSView()
        dimView.wantsLayer = true
        dimView.layer?.backgroundColor = NSColor(white: 0, alpha: Self.dimAlpha).cgColor
        dimView.layer?.cornerCurve = .continuous
        window.contentView = dimView
        self.window = window
        return window
    }
}
