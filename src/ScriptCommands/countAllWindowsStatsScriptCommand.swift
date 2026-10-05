import Foundation
import Cocoa

class countAllWindowStatsScriptCommand: NSScriptCommand {

    override func performDefaultImplementation() -> Any? {

        let list = NSAppleEventDescriptor.list()

        for app in Applications.list {
            let pid = app.pid

            var all = 0
            var cur = 0
            var minCur = 0

            for window in Windows.list {
                guard window.application.runningApplication.processIdentifier == pid else { continue }
                guard !window.isWindowlessApp else { continue }
                all += 1

                let inVisibleSpace =
                    window.spaceIds.contains { Spaces.visibleSpaces.contains($0) }

                if inVisibleSpace {
                    cur += 1
                    if window.isMinimized {
                        minCur += 1
                    }
                }
            }

            if all == 0 { continue }

            let record = NSAppleEventDescriptor.record()

            record.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(pid)),
                forKeyword: kPID
            )
            record.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(all)),
                forKeyword: kWin
            )
            record.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(cur)),
                forKeyword: kCur
            )
            record.setDescriptor(
                NSAppleEventDescriptor(int32: Int32(minCur)),
                forKeyword: kMin
            )

            list.insert(record, at: list.numberOfItems + 1)
        }

        return list
    }
}
