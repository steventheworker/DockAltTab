import Foundation
import Cocoa

class repositionThumbnailsScriptCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard
            let position = self.directParameter as? [NSNumber],
            position.count >= 2
        else { return self }

        if TilesPanel.shared.isVisible == false { return self }

        let targetX = position[0].intValue
        let targetY = position[1].intValue

        let startX = DockAltTabFORCEDX
        let startY = DockAltTabFORCEDY

        // Cancel any existing animation
        DockAltTabRepositionTimer?.invalidate()

        let duration: TimeInterval = 16.67 / 1000 * 2 // duration for 60 fps (16.67ms) * 2 = 30 fps
        let steps = floor(222 / (16.67 * 2))
        let interval = duration / Double(steps)
        var currentStep = 0

        DockAltTabRepositionTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = min(Double(currentStep) / Double(steps), 1.0)

            let newX = Double(startX) + (Double(targetX - startX) * progress)
            let newY = Double(startY) + (Double(targetY - startY) * progress)

            DockAltTabFORCEDX = Int(newX)
            DockAltTabFORCEDY = Int(newY)

            TilesPanel.shared.screen?.repositionPanel(TilesPanel.shared)

            if progress >= 1.0 {
                timer.invalidate()
                DockAltTabRepositionTimer = nil

                DockAltTabFORCEDX = targetX
                DockAltTabFORCEDY = targetY
            }
        }

        return self
    }
}
