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
    NSStatusItem *statusItem;
    IBOutlet NSMenu *menu; //menu icon contextmenu
    __weak IBOutlet NSButton *menuItemCheckBox;
    BOOL isMenuItemChecked;
    NSString* appVersion;
    NSString* mostCurrentVersion;
    __weak IBOutlet NSTextField *appVersionRef;
    __weak IBOutlet NSTextField *updateRemindRef;
}
@property BOOL isMenuItemChecked;
@end

