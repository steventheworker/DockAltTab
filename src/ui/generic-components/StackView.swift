import Cocoa

class StackView: NSStackView {
    convenience init(_ views: [NSView], _ orientation: NSUserInterfaceLayoutOrientation = .horizontal, _ shouldFit: Bool = true, top: CGFloat = 0, right: CGFloat = 0, bottom: CGFloat = 0, left: CGFloat = 0) {
        self.init(views: views)
        translatesAutoresizingMaskIntoConstraints = false
        edgeInsets = NSEdgeInsets(top: (DockAltTabMode ? 0 : top), left: (DockAltTabMode ? 0 : left), bottom: (DockAltTabMode ? 0 : bottom), right: (DockAltTabMode ? 0 : right))
        alignment = orientation == .horizontal ? .firstBaseline : .leading
        if shouldFit {
            // workaround: for some reason, horizontal stackviews with a RecorderControl have extra fittingSize.height
            if orientation == .horizontal && (views.contains { $0 is CustomRecorderControl }) {
                fit(fittingSize.width, fittingSize.height - 7)
            } else {
                fit()
            }
        }
    }
}
