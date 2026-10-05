// call hideUI()
import Foundation
import Cocoa

class HideScriptCommand: NSScriptCommand {
	override func performDefaultImplementation() -> Any? {
        App.hideUi()
        DockAltTabReset()
        return self
	}
}
