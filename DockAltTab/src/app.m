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
+ (instancetype) init: (NSWindow*) window : (NSMenu*) menu : (AXUIElementRef) systemWideAccessibilityElement {
    App* app = [[self alloc] init];
    
    // add new app instance's references
    app->permissionWindow = window;
    app->systemWideEl = systemWideAccessibilityElement;
    
    if (![app hasRequiredPermissions]) { //app shouldn't do anything until permissions are granted
        [app renderAndShowPermissionWindow];
        return app;
    }
    
    [app addMenuIcon: menu]; // adds menu icon / references
    
    //load nib/xib prefsWindow
    app->prefsController = [[NSWindowController alloc] initWithWindowNibName:@"prefs"];
    [app->prefsController loadWindow];
    
    [app startListening];
    
    return app;
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
    //mouse events
    [helperLib on: @"mousedown" : ^BOOL(CGEventTapProxy _Nonnull proxy, CGEventType type, CGEventRef  _Nonnull event, void * _Nonnull refcon) {
        NSLog(@"d");
        CGPoint cursorPos = CGEventGetLocation(event);
        AXUIElementRef element = NULL;
        
        // Create an AXUIElement for the element at the cursor position
        AXError result = AXUIElementCopyElementAtPosition(self->systemWideEl, cursorPos.x, cursorPos.y, &element);
        
        if (result == kAXErrorSuccess && element != NULL) {
            // Now you have an AXUIElementRef for the element under the cursor
            // You can use Accessibility API functions to inspect its properties
            // For example, to get the subrole:
            CFTypeRef subroleValue;
            result = AXUIElementCopyAttributeValue(element, kAXSubroleAttribute, &subroleValue);
            
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString *subrole = (__bridge NSString *)subroleValue;
                
                NSLog(@"%@",subrole);
            }
            
            // Release the AXUIElement
            CFRelease(element);
        }

        return YES;
    }];
    [helperLib on: @"mouseup" : ^BOOL(CGEventTapProxy _Nonnull proxy, CGEventType type, CGEventRef  _Nonnull event, void * _Nonnull refcon) {
        NSLog(@"u");
        return YES;
    }];
}
- (void) appBecameActive: (NSNotification*) notification {
    // don't raise prefs if sparkle updater visible (may open on launch (and triggers appBecameActive unintentionally))
    NSArray* windows = [[NSApplication sharedApplication] windows];
    // don't raise mainWindow if app already has a visible app (ignore menubar icon)
    for (NSWindow* cur in windows) if (cur.isVisible) {if (cur.level == NSStatusWindowLevel) continue; else return;}

    // raise main window
    [self openPrefs];
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
    //    [prefsController showWindow: [prefsController window]];
    [helperLib activateWindow: [prefsController window]];
}
@end
