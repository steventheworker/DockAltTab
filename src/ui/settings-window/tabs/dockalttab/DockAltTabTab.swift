import Cocoa

class DockAltTabTab {
    private static let modeTitles = [
        NSLocalizedString("MacOS", comment: "DockAltTab preview mode"),
        NSLocalizedString("Ubuntu", comment: "DockAltTab preview mode"),
        NSLocalizedString("Windows", comment: "DockAltTab preview mode"),
    ]
    private static let modeSubTitle = NSLocalizedString(
        "MacOS shows previews on hover with space switching. Ubuntu shows them on click without space switching. Windows shows them on hover without space switching.",
        comment: "DockAltTab preview mode explanation")
    private static let delaySubTitle = NSLocalizedString("Delays are ignored in Ubuntu mode.", comment: "DockAltTab delay explanation")
    private static let thumbnailsSubTitle = NSLocalizedString("Show a thumbnail preview when hovering a window in the dock.", comment: "DockAltTab thumbnails explanation")
    private static var modeControl: NSSegmentedControl?
    private static var showDelaySlider: NSSlider?
    private static var showDelayLabel: NSTextField?
    private static var hideDelaySlider: NSSlider?
    private static var hideDelayLabel: NSTextField?
    private static var thumbnailDelaySlider: NSSlider?
    private static var thumbnailDelayLabel: NSTextField?
    private static var thumbnailEnabledSwitch: Switch?
    private static var repositionAfterMagnificationSwitch: Switch?
    private static var gutterSlider: NSSlider?
    private static var gutterLabel: NSTextField?
    private static var keepDockShowingSwitch: Switch?
    private static var shiftClickSwitch: Switch?
    private static var optionClickSwitch: Switch?
    private static var cmdClickSwitch: Switch?

    static func initTab() -> NSView {
        let previewTable = TableGroupView(title: NSLocalizedString("Previews", comment: ""), subTitle: modeSubTitle, width: SettingsWindow.contentWidth)
        addModeRow(previewTable)
        (showDelaySlider, showDelayLabel) = addDelayRow(previewTable, NSLocalizedString("Show delay", comment: ""), DockAltTabPreferences.previewDelay) {
            DockAltTabPreferences.previewDelay = $0
        }
        (hideDelaySlider, hideDelayLabel) = addDelayRow(previewTable, NSLocalizedString("Hide delay", comment: ""), DockAltTabPreferences.previewHideDelay) {
            DockAltTabPreferences.previewHideDelay = $0
        }
        (thumbnailDelaySlider, thumbnailDelayLabel) = addDelayRow(previewTable, NSLocalizedString("Thumbnail preview delay", comment: ""), DockAltTabPreferences.thumbnailPreviewDelay) {
            DockAltTabPreferences.thumbnailPreviewDelay = $0
        }
        thumbnailEnabledSwitch = addSwitchRow(previewTable, NSLocalizedString("Enable thumbnail previews", comment: ""), thumbnailsSubTitle, DockAltTabPreferences.thumbnailPreviewsEnabled) {
            DockAltTabPreferences.thumbnailPreviewsEnabled = $0
        }
        repositionAfterMagnificationSwitch = addSwitchRow(previewTable, NSLocalizedString("Reposition preview after dock magnification", comment: ""), nil, DockAltTabPreferences.repositionPreviewAfterMagnification) {
            DockAltTabPreferences.repositionPreviewAfterMagnification = $0
        }
        let dockTable = TableGroupView(title: NSLocalizedString("Dock", comment: ""), width: SettingsWindow.contentWidth)
        (gutterSlider, gutterLabel) = addGutterRow(dockTable)
        keepDockShowingSwitch = addSwitchRow(dockTable, NSLocalizedString("Keep dock showing during previews", comment: ""), NSLocalizedString("Only applies when the dock auto-hides.", comment: ""), DockAltTabPreferences.keepDockShowing) {
            DockAltTabPreferences.keepDockShowing = $0
        }
        addModifierClickRow(dockTable)
        refreshControlsFromPreferences()
        return TableGroupSetView(originalViews: [previewTable, dockTable], bottomPadding: 0)
    }

    static func refreshControlsFromPreferences() {
        modeControl?.selectedSegment = selectedModeSegment()
        thumbnailEnabledSwitch?.state = DockAltTabPreferences.thumbnailPreviewsEnabled ? .on : .off
        repositionAfterMagnificationSwitch?.state = DockAltTabPreferences.repositionPreviewAfterMagnification ? .on : .off
        keepDockShowingSwitch?.state = DockAltTabPreferences.keepDockShowing ? .on : .off
        shiftClickSwitch?.state = DockAltTabPreferences.shiftClickOpensNewWindow ? .on : .off
        optionClickSwitch?.state = DockAltTabPreferences.optionClickShowsContextMenu ? .on : .off
        cmdClickSwitch?.state = DockAltTabPreferences.cmdClickCyclesWindows ? .on : .off
        showDelaySlider?.doubleValue = DockAltTabPreferences.previewDelay
        hideDelaySlider?.doubleValue = DockAltTabPreferences.previewHideDelay
        thumbnailDelaySlider?.doubleValue = DockAltTabPreferences.thumbnailPreviewDelay
        gutterSlider?.doubleValue = DockAltTabPreferences.previewGutter
        renderValueLabels()
    }

    private static func addModeRow(_ table: TableGroupView) {
        let control = NSSegmentedControl(labels: modeTitles, trackingMode: .selectOne, target: nil, action: nil)
        control.translatesAutoresizingMaskIntoConstraints = false
        LabelAndControl.applySystemSelectedSegmentStyle(control)
        control.onAction = { sender in
            DockAltTabPreferences.previewMode = (sender as! NSSegmentedControl).selectedSegment + 1
        }
        modeControl = control
        table.addRow(leftText: NSLocalizedString("Preview mode", comment: ""), rightViews: [control])
    }

    private static func addDelayRow(_ table: TableGroupView, _ title: String, _ value: Double, _ onChange: @escaping (Double) -> Void) -> (NSSlider, NSTextField) {
        let (slider, label) = makeSlider(value, minValue: 0, maxValue: 100, numberOfTickMarks: 5, width: 180)
        slider.onAction = { sender in
            onChange((sender as! NSSlider).doubleValue)
            renderValueLabels()
        }
        table.addRow(leftText: title, rightViews: [slider, label], subText: delaySubTitle)
        return (slider, label)
    }

    private static func addModifierClickRow(_ table: TableGroupView) {
        let shiftTip = NSLocalizedString("Shift-click a Dock icon to ask the app for a new window.", comment: "")
        let optionTip = NSLocalizedString("Option-click a Dock icon to show the Dock's context menu instead of hiding the app.", comment: "")
        let cmdTip = NSLocalizedString("Command-click a Dock icon to cycle through the app's windows.", comment: "")
        let shift = addModifierToggle(NSLocalizedString("New window ⇧", comment: ""), shiftTip, DockAltTabPreferences.shiftClickOpensNewWindow) {
            DockAltTabPreferences.shiftClickOpensNewWindow = $0
        }
        let option = addModifierToggle(NSLocalizedString("Context menu ⌥", comment: ""), optionTip, DockAltTabPreferences.optionClickShowsContextMenu) {
            DockAltTabPreferences.optionClickShowsContextMenu = $0
        }
        let cmd = addModifierToggle(NSLocalizedString("Cycle windows ⌘", comment: ""), cmdTip, DockAltTabPreferences.cmdClickCyclesWindows) {
            DockAltTabPreferences.cmdClickCyclesWindows = $0
        }
        shiftClickSwitch = shift.0
        optionClickSwitch = option.0
        cmdClickSwitch = cmd.0
        let row = NSStackView(views: [shift.1, option.1, cmd.1])
        row.orientation = .horizontal
        row.spacing = 14
        row.alignment = .centerY
        table.addRow(leftText: NSLocalizedString("Modifier clicks", comment: ""), rightViews: [row])
    }

    private static func addModifierToggle(_ title: String, _ toolTip: String, _ value: Bool, _ onChange: @escaping (Bool) -> Void) -> (Switch, NSView) {
        let control = Switch(value)
        control.onAction = { sender in
            onChange((sender as! NSButton).state == .on)
        }
        control.toolTip = toolTip
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        let group = NSStackView(views: [label, control])
        group.orientation = .horizontal
        group.spacing = 5
        group.alignment = .centerY
        group.toolTip = toolTip
        return (control, group)
    }

    private static func addGutterRow(_ table: TableGroupView) -> (NSSlider, NSTextField) {
        let (slider, label) = makeSlider(DockAltTabPreferences.previewGutter, minValue: -200, maxValue: 200, numberOfTickMarks: 3, width: 180)
        slider.onAction = { sender in
            DockAltTabPreferences.previewGutter = (sender as! NSSlider).doubleValue
            renderValueLabels()
        }
        table.addRow(leftText: NSLocalizedString("Preview distance", comment: ""), rightViews: [slider, label], subText: NSLocalizedString("Distance between the previews and the dock, in pixels.", comment: ""))
        return (slider, label)
    }

    private static func makeSlider(_ value: Double, minValue: Double, maxValue: Double, numberOfTickMarks: Int, width: CGFloat) -> (NSSlider, NSTextField) {
        let slider = NSSlider(value: value, minValue: minValue, maxValue: maxValue, target: nil, action: nil)
        slider.isContinuous = true
        slider.numberOfTickMarks = numberOfTickMarks
        slider.tickMarkPosition = .above
        slider.translatesAutoresizingMaskIntoConstraints = false
        slider.widthAnchor.constraint(equalToConstant: width).isActive = true
        let label = NSTextField(labelWithString: "")
        label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        label.widthAnchor.constraint(equalToConstant: 56).isActive = true
        return (slider, label)
    }

    private static func addSwitchRow(_ table: TableGroupView, _ title: String, _ subTitle: String?, _ value: Bool, _ onChange: @escaping (Bool) -> Void) -> Switch {
        let control = Switch(value)
        control.onAction = { sender in
            onChange((sender as! NSButton).state == .on)
        }
        table.addRow(leftText: title, rightViews: [control], subText: subTitle)
        return control
    }

    private static func selectedModeSegment() -> Int {
        min(max(DockAltTabPreferences.previewMode - 1, 0), modeTitles.count - 1)
    }

    private static func renderValueLabels() {
        showDelayLabel?.stringValue = formatSeconds(DockAltTabPreferences.previewDelay)
        hideDelayLabel?.stringValue = formatSeconds(DockAltTabPreferences.previewHideDelay)
        thumbnailDelayLabel?.stringValue = formatSeconds(DockAltTabPreferences.thumbnailPreviewDelay)
        gutterLabel?.stringValue = formatPixels(DockAltTabPreferences.previewGutter)
    }

    private static func formatSeconds(_ value: Double) -> String {
        String(format: "%.2f s", value / 100 * 2)
    }

    private static func formatPixels(_ value: Double) -> String {
        (value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)) + " px"
    }
}
