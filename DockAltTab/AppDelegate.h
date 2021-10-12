//
//  AppDelegate.h
//  DockAltTab (4)
//
//  Created by Steven G on 9/6/21.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    //publics
    @public NSMutableString  *targetApp;
    @public NSMutableString  *dockPos;
    @public pid_t           overlayPID;
    @public int             numFinderProcesses;
    
    BOOL                    isMenuItemChecked;
    pid_t                   dockPID;
    AXUIElementRef          _systemWideAccessibilityObject;
    NSTimer                 *timer;
    NSDictionary            *appAliases;
    NSStatusItem            *statusItem;
    NSString*               appVersion;
    NSString*               mostCurrentVersion;
    
    //ui connections
    IBOutlet NSMenu *menu;
    __weak IBOutlet NSButton *menuItemCheckBox;
    __weak IBOutlet NSTextField *appVersionRef;
    __weak IBOutlet NSTextField *updateRemindRef;
}
@property BOOL isMenuItemChecked;
@end

