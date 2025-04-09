//
//  app.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "app.h"
#import "globals.h"
#import "helperLib.h"
#import "prefs.h"
#import "prefsWindowController.h"
#import "DockAltTab.h"
#import "SupportedAltTabAttacher.h"

NSSet<NSRunningApplication*>* previousValueOfRunningApps;
@implementation App
+ (instancetype) init: (NSWindow*) window : (NSMenu*) iconMenu : (AXUIElementRef) systemWideAccessibilityElement {
    App* app = [[self alloc] init];
    
    // add new app instance's references
    app->permissionWindow = window;
    app->systemWideEl = systemWideAccessibilityElement;
    
    if (![app hasRequiredPermissions]) { //app shouldn't do anything until permissions are granted
        [app renderAndShowPermissionWindow];
        return app;
    }
    
    [app addMenuIcon: iconMenu]; // adds menu icon / references
    
    //load nib/xib prefsWindow
    app->prefsController = [prefsWindowController.alloc initWithWindowNibName: @"prefs"];
    [app->prefsController loadWindow];
    
    [app mousemoveLess: [prefs getIntPref: @"previewMode"] == 2 && ![prefs getBoolPref: @"thumbnailPreviewsEnabled"]]; // ubuntu is mousemoveless
    [app startListening];
    [DockAltTab init];
    
    setTimeout(^{app->isSparkleUpdaterOpen = helperLib.isSparkleUpdaterOpen;}, 1000);
    return app;
}

- (void) addMenuIcon: (NSMenu*) menu {
    iconMenu = menu;
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage: [NSImage imageNamed: @"MenuIcon"]];
    [statusItem setMenu: iconMenu];
    [statusItem setVisible: YES]; //without this, could stay hidden away
}

/* event listening */
- (void) mousemoveLess: (BOOL) yesno {mousemoveLess = yesno;}
- (void) startListening {
    /* observers */
    // on app became active (open prefs window)
    [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(appBecameActive:) name: NSApplicationDidBecomeActiveNotification object: nil];
    // on app window closed
    [NSNotificationCenter.defaultCenter addObserver: self selector: @selector(windowWillClose:) name: NSWindowWillCloseNotification object: nil];
    //on space change
    [NSWorkspace.sharedWorkspace.notificationCenter addObserverForName: NSWorkspaceActiveSpaceDidChangeNotification object: NSWorkspace.sharedWorkspace queue: nil usingBlock:^(NSNotification * _Nonnull note) {
        [DockAltTab spaceChanged: note];
    }];
    
    //on app launched/terminated
    previousValueOfRunningApps = [NSSet setWithArray: NSWorkspace.sharedWorkspace.runningApplications];
    [NSWorkspace.sharedWorkspace addObserver: self forKeyPath: @"runningApplications" options: /*NSKeyValueObservingOptionOld | */ NSKeyValueObservingOptionNew context: NULL];

    /* cgeventtap's */
    //mouse events
    [helperLib on: @"mousedown" : ^BOOL(CGEventTapProxy _Nonnull proxy, CGEventType type, CGEventRef  _Nonnull event, void * _Nonnull refcon) {
        if (self->mousemoveLess) self->cursorPos = CGEventGetLocation(event);
        if (self->isSparkleUpdaterOpen) return YES; // elementAtPoint crashes app when put on the release notes webview
        if (self->mousemoveLess) [DockAltTab mousemove: proxy : type : event : refcon : self->cursorPos]; //update DockAltTab.m cursorPos
        if (![DockAltTab mousedown: proxy : type : event : refcon]) return NO;
        return YES;
    }];
    [helperLib on: @"mouseup" : ^BOOL(CGEventTapProxy _Nonnull proxy, CGEventType type, CGEventRef  _Nonnull event, void * _Nonnull refcon) {
        if (self->mousemoveLess) self->cursorPos = CGEventGetLocation(event);
        if (self->isSparkleUpdaterOpen) return YES; // elementAtPoint crashes app when put on the release notes webview
        if (self->mousemoveLess) [DockAltTab mousemove: proxy : type : event : refcon : self->cursorPos]; //update DockAltTab.m cursorPos
        if (![DockAltTab mouseup: proxy : type : event : refcon]) return NO;
        return YES;
    }];
    [helperLib on: @"mousemove" : ^BOOL(CGEventTapProxy _Nonnull proxy, CGEventType type, CGEventRef  _Nonnull event, void * _Nonnull refcon) {
        if (self->mousemoveLess) return YES; //Ubuntu mode doesn't use mousemove, and getting coordinates causes issues with PowerPoint (notes section)
        if (self->isSparkleUpdaterOpen) return YES; // elementAtPoint crashes app when put on the release notes webview
        self->cursorPos = CGEventGetLocation(event);
        if (![DockAltTab mousemove: proxy : type : event : refcon : self->cursorPos]) return NO;
        return YES;
    }];
}
- (void) windowWillClose: (NSNotification*) notification { // notify when one of our app windows closes
    setTimeout(^{
        self->isSparkleUpdaterOpen = [helperLib isSparkleUpdaterOpen];NSLog(@"%d", self->isSparkleUpdaterOpen);
    }, 0);
}
- (void) appBecameActive: (NSNotification*) notification {
    // don't raise prefs if sparkle updater visible (may open on launch (and triggers appBecameActive unintentionally))
    NSArray* windows = [[NSApplication sharedApplication] windows];
    // don't raise mainWindow if app already has a visible app (ignore menubar icon)
    for (NSWindow* cur in windows) if (cur.isVisible) {if (cur.level == NSStatusWindowLevel) continue; else return;}

    // raise main window
    [self openPrefs];
}
- (void)appLaunched: (NSRunningApplication*) app {
//    NSLog(@"App launched: %@ — '%@' — %d", app.bundleIdentifier, app.localizedName, app.processIdentifier);
    if ([app.bundleIdentifier isEqual: @"com.steventheworker.alt-tab-macos"] || [app.bundleIdentifier isEqual: @"com.lwouis.alt-tab-macos"])
        setTimeout(^{[SupportedAltTabAttacher init: ^{[DockAltTab loadAltTabPID];}];}, 1000); //AltTab takes a sec to finish launch
    if ([app.bundleIdentifier isEqual: @"com.apple.dock"]) [DockAltTab loadDockPID];
}

- (void)appTerminated :(NSRunningApplication*) app {
//    NSLog(@"App terminated: %@ — '%@' — %d", app.bundleIdentifier, app.localizedName, app.processIdentifier);
    if ([app.bundleIdentifier isEqual: @"com.steventheworker.alt-tab-macos"] || [app.bundleIdentifier isEqual: @"com.lwouis.alt-tab-macos"])
        setTimeout(^{[SupportedAltTabAttacher init: ^{[DockAltTab loadAltTabPID];}];}, 333);
}

//observe any nsrunningapps list change (ie: forKeyPath: @"runningApplications)
NSSet* runningApps;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    NSSet<NSRunningApplication*>* workspaceApps = [NSSet setWithArray: NSWorkspace.sharedWorkspace.runningApplications];
    NSMutableSet<NSRunningApplication*>* diff = [workspaceApps mutableCopy];
    [diff minusSet: previousValueOfRunningApps];
    for (NSRunningApplication* app in diff) [self appLaunched: app];
    NSMutableSet<NSRunningApplication*>* terminatedApps = [previousValueOfRunningApps mutableCopy];
    [terminatedApps minusSet: workspaceApps];
    for (NSRunningApplication* app in terminatedApps) [self appTerminated: app];
    previousValueOfRunningApps = workspaceApps;
}



- (BOOL) hasRequiredPermissions { // also adds permission entries into settings
    BOOL hasAccessibility = AXIsProcessTrustedWithOptions(NULL);
//    IOHIDRequestAccess(kIOHIDRequestTypeListenEvent); // add input monitoring entry in settings (has to run as start of app lifecycle (will not work any later))
//    BOOL hasInputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOReturnSuccess;
//    BOOL hasScreenRecording = CGPreflightScreenCaptureAccess();
    return hasAccessibility;
}
/* rendering - app windows (eg: permissionWindow, prefsWindow (via: [app->prefsController window]), etc.) */
- (void) renderAndShowPermissionWindow {
    [helperLib activateWindow: self->permissionWindow];
    //render
    NSView *mainView = [self->permissionWindow contentView];
    for (NSView *subview in [mainView subviews]) {
        if ([subview isKindOfClass:[NSButton class]]) {
            NSButton *button = (NSButton *)subview;
            [button setFocusRingType:NSFocusRingTypeNone]; // Remove NSFocusRing (focus border/outline)
            //colorize on/off permissions
            if ([button.title isEqual: @"Accessibility"] && AXIsProcessTrustedWithOptions(NULL)) [button setBezelColor: [NSColor systemGreenColor]];
            if ([button.title isEqual: @"Input Monitoring"] && IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOReturnSuccess) [button setBezelColor: [NSColor systemGreenColor]];
            if ([button.title isEqual: @"Screen Recording"] && CGPreflightScreenCaptureAccess()) [button setBezelColor: [NSColor systemGreenColor]];
        }
    }
}
- (void) openPrefs {
    [[prefsController window] setIsVisible: YES];
    [prefsController render];
    //    [prefsController showWindow: [prefsController window]];
    [helperLib activateWindow: [prefsController window]];
}
@end
