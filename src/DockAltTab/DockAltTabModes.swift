import Foundation

/// The AltTab shortcut index reserved for DockAltTab (shown as "DockAltTab" in the controls settings).
let dockAltTabShortcutIndex = 2

/// The three DockAltTab interaction styles, migrated from the original app.
enum DockAltTabPreviewMode: Int {
    /// Hover shows previews; clicks behave like the native Dock.
    case macos = 1
    /// No hover previews; clicks toggle previews/apps.
    case ubuntu = 2
    /// Hover shows previews; clicks toggle the app (with space-swoosh prevention).
    case windows = 3

    static var current: DockAltTabPreviewMode {
        DockAltTabPreviewMode(rawValue: DockAltTabPreferences.previewMode) ?? .windows
    }

    var showsPreviewOnHover: Bool { self != .ubuntu }
    var interceptsDockClicks: Bool { self != .macos }
}
