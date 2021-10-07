//
//  AppDelegate.h
//  DockAltTab (4)
//
//  Created by Steven G on 9/6/21.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    AXUIElementRef          _systemWideAccessibilityObject;
    NSTimer                 *timer;
    @public NSMutableString  *targetApp;
    NSDictionary            *appAliases;
    @public NSMutableString  *dockPos;
    pid_t                   dockPID;
    @public pid_t           overlayPID;
    BOOL isMenuItemChecked;
    NSStatusItem *statusItem;
    IBOutlet NSMenu *menu;
    __weak IBOutlet NSButton *menuItemCheckbox;
}
@property BOOL isMenuItemChecked;
@end

