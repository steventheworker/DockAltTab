import Cocoa

/// The standalone DockAltTab preferences. It intentionally exposes only the "Preview Settings"
/// box from the original app; the rest of the configuration lives in AltTab's own settings.
class DockAltTabPreferencesWindow: NSWindow {
    static var shared: DockAltTabPreferencesWindow?
    static var canBecomeKey_ = true
    override var canBecomeKey: Bool { Self.canBecomeKey_ }

    private var modeButtons: [Int: NSButton] = [:]
    private var showDelaySlider: NSSlider!
    private var showDelayLabel: NSTextField!
    private var hideDelaySlider: NSSlider!
    private var hideDelayLabel: NSTextField!
    private var thumbnailDelaySlider: NSSlider!
    private var thumbnailDelayLabel: NSTextField!
    private var thumbnailEnabledCheckbox: NSButton!
    private var gutterSlider: NSSlider!
    private var gutterLabel: NSTextField!
    private var keepDockCheckbox: NSButton!
    private var repositionAfterMagnificationCheckbox: NSButton!

    convenience init() {
        self.init(contentRect: NSRect(x: 0, y: 0, width: 420, height: 390), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        title = "DockAltTab Preferences"
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        setupView()
        setFrameAutosaveName("DockAltTabPreferencesWindow")
        render()
        Self.shared = self
    }

    private func setupView() {
        let box = NSBox()
        box.title = "Preview Settings"
        box.titlePosition = .atTop
        box.translatesAutoresizingMaskIntoConstraints = false
        let inner = NSView()
        box.contentView = inner

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        inner.addSubview(stack)

        stack.addArrangedSubview(makeModeRow())
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeDelayRow("Show Delay:", tooltip: "The delay before showing a preview. Does not apply to Ubuntu mode.", slider: &showDelaySlider, valueLabel: &showDelayLabel) { sender in
            DockAltTabPreferences.previewDelay = sender.doubleValue
        })
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeDelayRow("Hide Delay:", tooltip: "The delay before hiding previews. Does not apply to Ubuntu mode.", slider: &hideDelaySlider, valueLabel: &hideDelayLabel) { sender in
            DockAltTabPreferences.previewHideDelay = sender.doubleValue
        })
        stack.addArrangedSubview(makeSeparator())
        stack.addArrangedSubview(makeDelayRow("Thumbnail Preview Delay:", tooltip: "The delay before showing a thumbnail's preview.", slider: &thumbnailDelaySlider, valueLabel: &thumbnailDelayLabel) { sender in
            DockAltTabPreferences.thumbnailPreviewDelay = sender.doubleValue
        })

        thumbnailEnabledCheckbox = NSButton(checkboxWithTitle: "Enable Thumbnail Previews", target: nil, action: nil)
        thumbnailEnabledCheckbox.font = .systemFont(ofSize: 11)
        thumbnailEnabledCheckbox.onAction = { sender in
            DockAltTabPreferences.thumbnailPreviewsEnabled = (sender as! NSButton).state == .on
        }
        stack.addArrangedSubview(thumbnailEnabledCheckbox)

        repositionAfterMagnificationCheckbox = NSButton(checkboxWithTitle: "Reposition preview after dock magnification", target: nil, action: nil)
        repositionAfterMagnificationCheckbox.font = .systemFont(ofSize: 11)
        repositionAfterMagnificationCheckbox.toolTip = "Move the preview panel once the Dock icon has finished magnifying."
        repositionAfterMagnificationCheckbox.onAction = { sender in
            DockAltTabPreferences.repositionPreviewAfterMagnification = (sender as! NSButton).state == .on
        }
        stack.addArrangedSubview(repositionAfterMagnificationCheckbox)
        stack.addArrangedSubview(makeSeparator())

        stack.addArrangedSubview(makeGutterRow())
        stack.addArrangedSubview(makeSeparator())

        keepDockCheckbox = NSButton(checkboxWithTitle: "Keep dock showing during previews", target: nil, action: nil)
        keepDockCheckbox.font = .systemFont(ofSize: 11)
        keepDockCheckbox.toolTip = "Maintain dock visibility when hovering over previews. (with autohide turned on)"
        keepDockCheckbox.onAction = { sender in
            DockAltTabPreferences.keepDockShowing = (sender as! NSButton).state == .on
        }
        stack.addArrangedSubview(keepDockCheckbox)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: inner.topAnchor, constant: 10),
            stack.leadingAnchor.constraint(equalTo: inner.leadingAnchor, constant: 12),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: inner.trailingAnchor, constant: -12),
            stack.bottomAnchor.constraint(equalTo: inner.bottomAnchor, constant: -10),
        ])

        let root = NSView()
        root.addSubview(box)
        NSLayoutConstraint.activate([
            box.topAnchor.constraint(equalTo: root.topAnchor, constant: 16),
            box.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 16),
            box.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -16),
            box.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -16),
        ])
        contentView = root
    }

    private func makeModeRow() -> NSView {
        let label = NSTextField(labelWithString: "Mode:")
        label.font = .systemFont(ofSize: 11)
        label.alignment = .right
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 12
        row.alignment = .centerY
        row.addArrangedSubview(label)
        for (tag, name, tooltip) in [
            (1, "MacOS", "Previews on hover w/ space switching. (Equivalent to 'Windows' mode (for now))"),
            (2, "Ubuntu", "Left/Middle click shows previews w/ no space switching."),
            (3, "Windows", "Windows™ Style - previews on hover w/ no space switching.")] {
            let button = NSButton(radioButtonWithTitle: name, target: nil, action: nil)
            button.font = .systemFont(ofSize: 11)
            button.tag = tag
            button.toolTip = tooltip
            button.focusRingType = .none
            button.onAction = { [weak self] sender in
                DockAltTabPreferences.previewMode = (sender as! NSButton).tag
                self?.render()
            }
            modeButtons[tag] = button
            row.addArrangedSubview(button)
        }
        return row
    }

    private func makeDelayRow(_ title: String, tooltip: String, slider: inout NSSlider!, valueLabel: inout NSTextField!, onChange: @escaping (NSSlider) -> Void) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11)
        label.alignment = .right
        label.toolTip = tooltip
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let s = NSSlider(value: 0, minValue: 0, maxValue: 100, target: nil, action: nil)
        s.isContinuous = true
        s.numberOfTickMarks = 5
        s.tickMarkPosition = .above
        s.toolTip = tooltip
        s.widthAnchor.constraint(equalToConstant: 110).isActive = true
        s.onAction = { [weak self] sender in
            onChange(sender as! NSSlider)
            self?.renderDelayLabels()
        }
        slider = s
        let value = NSTextField(labelWithString: "")
        value.font = .systemFont(ofSize: 11)
        value.alignment = .center
        value.toolTip = tooltip
        value.widthAnchor.constraint(equalToConstant: 40).isActive = true
        valueLabel = value
        let unit = NSTextField(labelWithString: "second(s)")
        unit.font = .systemFont(ofSize: 10)
        unit.toolTip = tooltip
        let row = NSStackView(views: [label, s, value, unit])
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        return row
    }

    private func makeGutterRow() -> NSView {
        let tooltip = "Adjust the distance between previews and the dock."
        let label = NSTextField(labelWithString: "Preview Distance:")
        label.font = .systemFont(ofSize: 11)
        label.alignment = .right
        label.toolTip = tooltip
        label.widthAnchor.constraint(equalToConstant: 110).isActive = true
        let s = NSSlider(value: 0, minValue: -200, maxValue: 200, target: nil, action: nil)
        s.isContinuous = true
        s.numberOfTickMarks = 3
        s.tickMarkPosition = .above
        s.toolTip = tooltip
        s.widthAnchor.constraint(equalToConstant: 110).isActive = true
        s.onAction = { [weak self] sender in
            DockAltTabPreferences.previewGutter = (sender as! NSSlider).doubleValue
            self?.renderDelayLabels()
        }
        gutterSlider = s
        let value = NSTextField(labelWithString: "")
        value.font = .systemFont(ofSize: 11)
        value.alignment = .center
        value.toolTip = tooltip
        value.widthAnchor.constraint(equalToConstant: 40).isActive = true
        gutterLabel = value
        let unit = NSTextField(labelWithString: "px")
        unit.font = .systemFont(ofSize: 10)
        unit.toolTip = tooltip
        let row = NSStackView(views: [label, s, value, unit])
        row.orientation = .horizontal
        row.spacing = 6
        row.alignment = .centerY
        return row
    }

    private func makeSeparator() -> NSBox {
        let separator = NSBox()
        separator.boxType = .separator
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.widthAnchor.constraint(equalToConstant: 340).isActive = true
        return separator
    }

    func render() {
        for (tag, button) in modeButtons {
            button.state = DockAltTabPreferences.previewMode == tag ? .on : .off
        }
        showDelaySlider.doubleValue = DockAltTabPreferences.previewDelay
        hideDelaySlider.doubleValue = DockAltTabPreferences.previewHideDelay
        thumbnailDelaySlider.doubleValue = DockAltTabPreferences.thumbnailPreviewDelay
        gutterSlider.doubleValue = DockAltTabPreferences.previewGutter
        thumbnailEnabledCheckbox.state = DockAltTabPreferences.thumbnailPreviewsEnabled ? .on : .off
        repositionAfterMagnificationCheckbox.state = DockAltTabPreferences.repositionPreviewAfterMagnification ? .on : .off
        keepDockCheckbox.state = DockAltTabPreferences.keepDockShowing ? .on : .off
        renderDelayLabels()
    }

    private func renderDelayLabels() {
        showDelayLabel.stringValue = formatSeconds(DockAltTabPreferences.previewDelay)
        hideDelayLabel.stringValue = formatSeconds(DockAltTabPreferences.previewHideDelay)
        thumbnailDelayLabel.stringValue = formatSeconds(DockAltTabPreferences.thumbnailPreviewDelay)
        let gutter = DockAltTabPreferences.previewGutter
        gutterLabel.stringValue = gutter == gutter.rounded() ? String(Int(gutter)) : String(format: "%.1f", gutter)
    }

    private func formatSeconds(_ value: Double) -> String {
        String(format: "%.2f", value / 100 * 2)
    }
}
