//show the default UI (cmd+tab / normally Shortcut1), but with 1st window highlighted
import Foundation
import Cocoa

class ShowScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
//        App.showUi()
        App.appIsBeingUsed = true
        App.showUiOrCycleSelection(0, true)
        App.previousWindowShortcutWithRepeatingKey()
        return self
    }
}
