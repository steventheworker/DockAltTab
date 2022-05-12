//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import "AppDelegate.h"
#import "src/helperLib.h"
#import "src/app.h"

void showOverlay(NSString* appBID) {
    AppDelegate* del = [helperLib getApp];
    if ([del->appDisplayed isEqual:appBID]) return;
    if (![del->appDisplayed isEqual:@""]) [app AltTabHide]; // hide other apps previews
    del->appDisplayed = appBID;
    [app AltTabShow:appBID];
}
void hideOverlay(void) {
    AppDelegate* del = [helperLib getApp];
    if ([del->appDisplayed isEqual:@""]) return;
    del->appDisplayed = @"";
    [app AltTabHide];
}

@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end
@implementation AppDelegate
    @synthesize isMenuItemChecked;
    @synthesize isClickToggleChecked;
    @synthesize previewDelay;
    @synthesize isLockDockContentsChecked;
    @synthesize isLockDockSizeChecked;
    @synthesize isLockDockPositionChecked;
/* app */
- (void)timerTick: (NSTimer*) arg {
    NSPoint mouseLocation = [NSEvent mouseLocation];
    CGPoint pt = [helperLib carbonPointFrom:mouseLocation];
    AXUIElementRef el = [helperLib elementAtPoint:pt];
    NSMutableDictionary* info = [NSMutableDictionary dictionaryWithDictionary: [helperLib axInfo:el]];
    pid_t tarPID = [info[@"PID"] intValue];
    if (tarPID == AltTabPID) return;
    NSString* tarBID = @"";
    if ([info[@"subrole"] isEqual:@"AXApplicationDockItem"]) {
        NSURL* appURL;
        AXUIElementCopyAttributeValue(el, kAXURLAttribute, (void*)&appURL);// BID w/ app url
        tarBID = [[NSBundle bundleWithURL:appURL] bundleIdentifier];
        tarPID = [helperLib getPID:tarBID]; // tarPID w/ BID
    } else { /* BID w/ tarPID */}
    
    // ? willShowOverlay
    BOOL willShow = [info[@"running"] intValue] && [info[@"subrole"] isEqual:@"AXApplicationDockItem"];
    int numWindows = willShow ? (int) [[helperLib getWindowsForOwnerPID:tarPID] count] : 0; // hidden / minimized windows not included
    if (willShow && [info[@"title"] isEqual:@"Parallels Mac VM"]) numWindows = 1; //if running - 1 window (but numWindows can't see it) //todo: why???
    if (willShow && numWindows == 0) {
        if ([helperLib runningAppFromAxTitle: info[@"title"]].isHidden) numWindows = 1;
        else numWindows = [helperLib numWindowsMinimized:info[@"title"]];
        if (numWindows == 0) willShow = NO;
    }
    
    willShow ? showOverlay(tarBID) : hideOverlay();
    NSLog(@"%@ %d",  willShow ? @"y" : @"n", numWindows);
}
- (void) dockItemClickHide:(CGPoint)carbonPoint :(NSDictionary *)info {
    
}
- (void) bindClick: (CGEventRef) e {
    NSLog(@"click");
}
- (void) bindScreens { //todo: 1 external display only atm 👁👄👁
    NSScreen* primScreen = [helperLib getScreen:0];
    NSScreen* extScreen = [helperLib getScreen:1];
    primaryScreenWidth = NSMaxX([primScreen frame]);
    primaryScreenHeight = NSMaxY([primScreen frame]);
    extScreenWidth = [extScreen frame].size.width;
    extScreenHeight =  [extScreen frame].size.height;
    extendedOffsetX = [extScreen frame].origin.x;
    extendedOffsetY = [extScreen frame].origin.y;
    extendedOffsetYBottom = !extScreen ? 0 : fabs(primaryScreenHeight - extScreenHeight) - extendedOffsetY;
}


/* UI */
- (IBAction) preferences:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:nil];
    if (!mostCurrentVersion)
        mostCurrentVersion = [app getCurrentVersion];
    [[appVersionRef cell] setTitle:[@"v" stringByAppendingString:appVersion]];
    if (mostCurrentVersion == NULL) [[updateRemindRef cell] setTitle: @"No internet; Update check failed"];
    else {
        if (mostCurrentVersion == appVersion) {
            [[updateRemindRef cell] setTitle: @"You're on the latest release."];
            [updateRemindRef setTextColor:[NSColor greenColor]];
        } else {
            [[updateRemindRef cell] setTitle: [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]]];
            [updateRemindRef setTextColor:[NSColor redColor]];
        }
    }
    [[updateRemindRef cell] setTitle: mostCurrentVersion == NULL ? @"No internet; Update check failed" : (mostCurrentVersion == appVersion) ? @"You're on the latest release." : [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]]];
}
- (void) awakeFromNib {
    //default, //todo: save pref to json file & load here
    isClickToggleChecked = YES;
    clickToggleCheckBox.state = YES;
    menuItemCheckBox.state = YES;
    //set menu bar item/icon
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage:[NSImage imageNamed:@"MenuIcon"]];
    [statusItem setMenu:menu];
    [statusItem setVisible:YES]; //without this, could stay hidden away
    if (!menuItemCheckBox.state) [statusItem setVisible:NO];
}
- (IBAction)toggleMenuIcon:(id)sender {[statusItem setVisible:isMenuItemChecked];}
- (IBAction)toggleToggleDockApps:(id)sender {[[NSUserDefaults standardUserDefaults] setBool: !((BOOL) clickToggleCheckBox.state) forKey:@"isClickToggleChecked"];}  // (!) default true
- (IBAction)changeDelay:(id)sender {
    [[delayLabel cell] setTitle: [helperLib twoSigFigs: previewDelaySlider.floatValue / 100 * 2]]; // set slider label text
    [[NSUserDefaults standardUserDefaults] setInteger:previewDelaySlider.intValue forKey:@"previewDelay"];
}
- (IBAction) quit:(id)sender {[NSApp terminate:nil];}
- (IBAction)toggleMenuItem:(id)sender {[statusItem setVisible:isMenuItemChecked];}
//dock settings
- (IBAction)lockDockPosition:(id)sender {[helperLib dockSetting: CFSTR("position-immutable") : (BOOL) lockDockPositionCheckbox.state];}
- (IBAction)lockDockSize:(id)sender {[helperLib dockSetting: CFSTR("size-immutable") : (BOOL) lockDockSizeCheckbox.state];}
- (IBAction)lockDockContents:(id)sender {[helperLib dockSetting: CFSTR("contents-immutable") : (BOOL) lockDockContentsCheckbox.state];}
- (IBAction)kill:(id)sender {
    [helperLib killDock];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * 1), dispatch_get_main_queue(), ^(void){
        self->dockPID = [helperLib getPID:@"com.apple.dock"];  //wait for new Dock process to relaunch so we can get the new PID
    });
}


/* Lifecycle */
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSLog(@"DockAltTab started");
    [app initVars];
    [helperLib listenClicks];
    [helperLib listenScreens];
}
- (void)dealloc {//    [super dealloc]; //todo: why doesn't this work
    [timer invalidate];
    timer = nil;
    if (_systemWideAccessibilityObject) CFRelease(_systemWideAccessibilityObject);
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {/* Insert code here to tear down your application */}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {return NO;}
@end
