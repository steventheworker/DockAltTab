import Cocoa

class RunningApplicationsEvents {
    private static var appsObserver: NSKeyValueObservation!

    static func observe() {
        // we can't observe NSWorkspace.didLaunchApplicationNotification or NSWorkspace.didTerminateApplicationNotification
        // these only trigger for some apps, mostly GUI app. We need to track all processes as any could spawn a window
        appsObserver = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new], changeHandler: { (_, change) in handleEvent(change) })
//        let timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
//            for i in 0..<18 { print("") }
//            let x = Windows.list.enumerated().map({ (i, w) in
//                return [i+1, w.cgWindowId ?? 0,
//                        w.application.localizedName != nil ? w.application.localizedName! : "",
//                        w.title != nil ? w.title! : "",
//                        w.isTabbed,
//                        w.referenceWindowForTabbedWindow() ?? 0,
//                        w.position ?? 0,
//                        w.size ?? 0,
//                        w.spaceIndexes,
//                        w.spaceIds,
//                        w.dockLabel != nil ? w.dockLabel! : "",
//                        w.isAppMainWindow(),
//                        w.isMinimized,
//                        w.isHidden,
//                        w.isFullscreen,
//                        w.isOnAllSpaces,
//                        w.lastFocusOrder,
//                        w.creationOrder,
//                        w.shouldShowTheUser,
//                        w.canBeClosed(),
//                        w.canBeMinDeminOrFullscreened()]
//            });
//            x.forEach { print($0) }
//        }
//        RunLoop.main.add(timer, forMode: .common)
    }

    private static func handleEvent(_ change: NSKeyValueObservedChange<[NSRunningApplication]>) {
        let launched = change.newValue
        let quit = change.oldValue
        if let launched {
            Logger.debug { "launched:\(launched.map { $0.debugId() })" }
            Applications.addRunningApplications(launched, true)
        }
        if let quit {
            Logger.debug { "quit:\(quit.map { $0.debugId() })" }
            Applications.removeRunningApplications(quit)
        }
    }
}
