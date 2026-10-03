import Cocoa

extension CGWindowID {
    func title() -> String? {
        cgProperty("kCGSWindowTitle", String.self)
    }

    func level() -> CGWindowLevel {
        var level = CGWindowLevel(0)
        CGSGetWindowLevel(CGS_CONNECTION, self, &level)
        return level
    }

    func spaces() -> [CGSSpaceID] {
        return CGSCopySpacesForWindows(CGS_CONNECTION, CGSSpaceMask.all.rawValue, [self] as CFArray) as! [CGSSpaceID]
    }

    /// WindowServer parent id for a batch of windows, from one IPC.
    /// 0 = a normal window (or a native tab member); non-zero = the document
    /// window an AppKit sheet / `addChildWindow:` child is attached to. Such a
    /// surface is represented by its parent, not previewed on its own.
    static func parents(of wids: [CGWindowID]) -> [CGWindowID: CGWindowID] {
        guard !wids.isEmpty else { return [:] }
        var parents = [CGWindowID: CGWindowID]()
        let query = SLSWindowQueryWindows(CGS_CONNECTION, wids as CFArray, Int32(wids.count)).takeRetainedValue()
        let iterator = SLSWindowQueryResultCopyWindows(query).takeRetainedValue()
        while SLSWindowIteratorAdvance(iterator) {
            parents[SLSWindowIteratorGetWindowID(iterator)] = SLSWindowIteratorGetParentID(iterator)
        }
        return parents
    }

    private func cgProperty<T>(_ key: String, _ type: T.Type) -> T? {
        var value: AnyObject?
        CGSCopyWindowProperty(CGS_CONNECTION, self, key as CFString, &value)
        return value as? T
    }
}
