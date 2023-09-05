//
//  app.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "app.h"
#import "helperLib.h"
#import "globals.h"

@implementation App
+ (instancetype) init: (NSWindow*) window : (NSMenu*) menu {
    App* app = [[self alloc] init];
    
    // add new app instance's references
    [app addMenuIcon: menu];
    app->permissionWindow = window;

    //load nib/xib prefsWindow
    app->prefsController = [[NSWindowController alloc] initWithWindowNibName:@"prefs"];
    [app->prefsController loadWindow];
    
    [app startListening];
    
    return app;
}
- (void) openPrefs {
    [[prefsController window] setIsVisible: YES];
//    [prefsController showWindow: [prefsController window]];
    [helperLib activateWindow: [prefsController window]];
}
- (void) addMenuIcon: (NSMenu*) menu {
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage: [NSImage imageNamed: @"MenuIcon"]];
    [statusItem setMenu: menu];
    [statusItem setVisible: YES]; //without this, could stay hidden away
}

/* event listening */
- (void) startListening {
    // on app became active (open prefs window)
    [[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(appBecameActive:) name: NSApplicationDidBecomeActiveNotification object: nil];
}
- (void) appBecameActive: (NSNotification*) notification {
    // don't raise prefs if sparkle updater visible (may open on launch (and triggers appBecameActive unintentionally))
    NSArray* windows = [[NSApplication sharedApplication] windows];  // window titles: "DockAltTab needs some permissions", "Item-0" (menubar "window" title), "DockAltTab - preferences", "" (Sparkle update window)
    for (NSWindow* cur in windows) if (cur.isVisible) if ([[cur title] isEqual: @""]) return;
    
    // raise prefs window
    [self openPrefs];
}
@end
