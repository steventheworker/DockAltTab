// check if keys held / AltTab shortcut is blocking other apps from seeing modifier key
// if AltTab overlay is open, it will be the first to absorb keys (and preventDefault) for shortcuts (eg: Command to select preview, Shift to go back); this makes other apps blind to mod keys
import Foundation
import Cocoa

class keyStateScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        let key = self.evaluatedArguments!["key"] as! String
        if (DockAltTabModDict[key] == nil) {return false}
        return DockAltTabModDict[key]
    }
}
