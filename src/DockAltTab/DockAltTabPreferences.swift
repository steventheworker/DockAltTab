import Foundation

/// Preferences for the standalone DockAltTab feature.
/// Kept in their own namespace so they don't collide with AltTab's own preferences.
enum DockAltTabPreferences {
    private static let prefix = "dockAltTab."
    private static var store: UserDefaults { UserDefaults.standard }

    // 1 = MacOS, 2 = Ubuntu, 3 = Windows (mirrors the original DockAltTab)
    static var previewMode: Int {
        get { int("previewMode", 1) } set { set("previewMode", newValue) }
    }
    static var previewDelay: Double {
        get { double("previewDelay", 0) } set { set("previewDelay", newValue) }
    }
    static var previewHideDelay: Double {
        get { double("previewHideDelay", 0) } set { set("previewHideDelay", newValue) }
    }
    static var thumbnailPreviewDelay: Double {
        get { double("thumbnailPreviewDelay", 25) } set { set("thumbnailPreviewDelay", newValue) }
    }
    static var thumbnailPreviewsEnabled: Bool {
        get { bool("thumbnailPreviewsEnabled", true) } set { set("thumbnailPreviewsEnabled", newValue) }
    }
    static var previewGutter: Double {
        get { double("previewGutter", 0) } set { set("previewGutter", newValue) }
    }
    static var keepDockShowing: Bool {
        get { bool("keepDockShowing", true) } set { set("keepDockShowing", newValue) }
    }

    // the sliders use a 0-100 scale where 100 == 2 seconds, like the original DockAltTab
    static var previewDelayMs: Int { Int(previewDelay * 20) }
    static var previewHideDelayMs: Int { Int(previewHideDelay * 20) }
    static var thumbnailPreviewDelayMs: Int { Int(thumbnailPreviewDelay * 20) }

    private static func int(_ key: String, _ fallback: Int) -> Int {
        store.object(forKey: prefix + key) == nil ? fallback : store.integer(forKey: prefix + key)
    }
    private static func double(_ key: String, _ fallback: Double) -> Double {
        store.object(forKey: prefix + key) == nil ? fallback : store.double(forKey: prefix + key)
    }
    private static func bool(_ key: String, _ fallback: Bool) -> Bool {
        store.object(forKey: prefix + key) == nil ? fallback : store.bool(forKey: prefix + key)
    }
    private static func set(_ key: String, _ value: Any) { store.set(value, forKey: prefix + key) }
}
