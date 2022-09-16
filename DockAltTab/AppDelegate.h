//
//  AppDelegate.h
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    //permissions
    @public AXUIElementRef          _systemWideAccessibilityObject;
    
    //system state (non-live / eg. periodically updated)
    @public float           primaryScreenHeight;
    @public float           primaryScreenWidth;
    @public float           extendedOffsetX;
    @public float           extendedOffsetY;
    @public float           extendedOffsetYBottom;
    @public float           extScreenWidth;
    @public float           extScreenHeight;
    @public CGFloat         dockWidth;
    @public CGFloat         dockHeight;
    @public NSString*       dockPos;
    pid_t                  dockPID;
    pid_t                  finderPID;
    pid_t                  AltTabPID;
    BOOL                   unsupportedAltTab;
    BOOL                   autohide;
    BOOL                   steviaOS;

    //app stuff
    NSString*              appVersion;
    NSString*              mostCurrentVersion;
    NSTimer*               timer;
    NSString*              appDisplayed;
    pid_t                  appDisplayedPID;
    NSString*              lastAppClickToggled;
    BOOL                   wasShowingContextMenu;

    //UI
    NSStatusItem            *statusItem;
    __weak IBOutlet NSMenu *menu;
    __weak IBOutlet NSTextField *appVersionRef;
    __weak IBOutlet NSTextField *delayLabel;
    __weak IBOutlet NSTextField *updateRemindRef;
    BOOL                    isMenuItemChecked;
    BOOL                    isClickToggleChecked;
    BOOL                    isReopenPreviewsChecked;
    BOOL                    isLockDockContentsChecked;
    BOOL                    isLockDockSizeChecked;
    BOOL                    isLockDockPositionChecked;
    int                     previewDelay;
    __weak IBOutlet NSButton *menuItemCheckBox;    
    __weak IBOutlet NSButton *clickToggleCheckBox;
    __weak IBOutlet NSButton *lockDockContentsCheckbox;
    __weak IBOutlet NSButton *lockDockSizeCheckbox;
    __weak IBOutlet NSButton *lockDockPositionCheckbox;
    __weak IBOutlet NSSliderCell *previewDelaySlider;
    __weak IBOutlet NSBox *unsupportedBox;
}
@property BOOL isMenuItemChecked;
@property BOOL isClickToggleChecked;
@property BOOL isReopenPreviewsChecked;
@property BOOL isLockDockContentsChecked;
@property BOOL isLockDockSizeChecked;
@property BOOL isLockDockPositionChecked;
@property int previewDelay;
//- (float) timeDiff;
- (void) dockItemClickHide: (CGPoint)carbonPoint : (AXUIElementRef) el : (NSDictionary*)info;
- (void) bindClick: (CGEventRef) e : (BOOL) clickToClose;
- (void) bindScreens;
- (void) enableClickToClose;
- (void) reopenDock;
- (void) reopenPreview: (NSString*) cachedApp;
- (IBAction) preferences:(id)sender;
@end
