//
//  app.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "app.h"
#import "helperLib.h"

//config
const NSString* versionLink = @"https://dockalttab.netlify.app/currentversion.txt";
const float TICK_DELAY = 0.16666665; // 0.33333 / 2   seconds
const float DELAY_MAX = 2; // seconds

//hardcoded apple details
const int CONTEXTDISTANCE = 150; //dock testPoint/contextmenu's approx. distance from pointer
const int DOCK_OFFSET = 5; //5 pixels

//define
NSString* lastShowStr = @"";

@implementation app
//initialize app variables (onLaunch)
+ (void) initVars {
    NSLog(@"DockAltTab started\n----------------------------------------------------------------------------");
    [helperLib listenClicks];
    [helperLib listenScreens];
    AppDelegate* del = [helperLib getApp];
    //functional
    [del bindScreens]; //load screen data
    del->appDisplayed = @"";
    del->appDisplayedPID = 0;
    del->lastAppClickToggled = @"";
    del->autohide = [helperLib dockautohide];
    del->dockPos = [helperLib getDockPosition];
    del->dockPID = [helperLib getPID:@"com.apple.dock"]; //todo: refresh dockPID every x or so?
    del->AltTabPID = [helperLib getPID:@"com.steventheworker.alt-tab-macos"];
    if (del->AltTabPID == 0) {
        del->unsupportedAltTab = YES;
        del->AltTabPID = [helperLib getPID:@"com.lwouis.alt-tab-macos"];
    }
    del->finderPID = [helperLib getPID:@"com.apple.Finder"];
    if ([helperLib getPID:@"com.hegenberg.BetterTouchTool"] != 0 && [[helperLib runScript:@"tell application \"BetterTouchTool\" to return get_number_variable \"steviaOS\""] isEqual:@"1"]) {
        del->steviaOS = YES;
    } else del->steviaOS = NO;
    NSLog(@"(%lu) finder windows/processes found after launch", [[helperLib getRealFinderWindows] count]);
    //UI variables
    del->appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    //permissions
    del->_systemWideAccessibilityObject = AXUIElementCreateSystemWide();
    //interval Timer @ TICK_DELAY seconds, check to render something / stop rendering when mouse enters/leaves the dock
    del->timer = [NSTimer scheduledTimerWithTimeInterval:TICK_DELAY
                                                        target:del
                                                      selector:NSSelectorFromString(@"timerTick:")
                                                      userInfo:nil
                                                       repeats:YES];
    [app bindSettings];
    NSLog(@"timer successfully started");

    //check for updates on launch
    del->mostCurrentVersion = [app getCurrentVersion];
    if (del->mostCurrentVersion != del->appVersion || del->unsupportedAltTab) {
        if (del->unsupportedAltTab) [del->unsupportedBox setHidden: NO];
        [del preferences:nil];
    }
    
}

/* UI */
+ (void) bindSettings {
    Boolean valid = false;
    AppDelegate* del = [helperLib getApp];
    //dock settings
    NSString* dockDelayStr = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("autohide-delay"), CFSTR("com.apple.dock")));
    del->dockDelay = !dockDelayStr ? 0.5 : [dockDelayStr floatValue]; //default 0.5
    del->isLockDockContentsChecked = CFPreferencesGetAppBooleanValue( CFSTR("contents-immutable"), CFSTR("com.apple.dock"), &valid);
    del->isLockDockSizeChecked = CFPreferencesGetAppBooleanValue( CFSTR("size-immutable"), CFSTR("com.apple.dock"), &valid);
    del->isLockDockPositionChecked = CFPreferencesGetAppBooleanValue( CFSTR("position-immutable"), CFSTR("com.apple.dock"), &valid);
    //DockAltTab settings
    del->isClickToggleChecked = ![[NSUserDefaults standardUserDefaults] boolForKey:@"isClickToggleChecked"]; // (!) default true
    del->isReopenPreviewsChecked = [[NSUserDefaults standardUserDefaults] boolForKey:@"isReopenPreviewsChecked"]; // (!) default false
    del->previewDelay = ((int) [[NSUserDefaults standardUserDefaults] integerForKey:@"previewDelay"]);
    [app syncUI];
}
+ (void) syncUI {
    AppDelegate* del = [helperLib getApp];
    //dock settings
    del->dockDelayInput.floatValue = del->dockDelay;
    del->lockDockContentsCheckbox.state = del->isLockDockContentsChecked;
    del->lockDockSizeCheckbox.state = del->isLockDockSizeChecked;
    del->lockDockPositionCheckbox.state = del->isLockDockPositionChecked;
    //DockAltTab settings
    del->clickToggleCheckBox.state = del->isClickToggleChecked;
    del->reopenPreviewsCheckbox.state = del->isReopenPreviewsChecked;
    [del->previewDelaySlider setFloatValue:del->previewDelay];
    [[del->delayLabel cell] setTitle: [helperLib twoSigFigs: del->previewDelaySlider.floatValue / 100 * 2]]; // change slider label
}
/* utilities that depend on (AppDelegate *) */
+ (BOOL) contextMenuExists:(CGPoint) carbonPoint : (NSDictionary*) info {
    AppDelegate* del = [helperLib getApp];
    if ([info[@"role"] isEqual:@"AXMenuItem"] || [info[@"role"] isEqual:@"AXMenu"]) return YES;
    int multiplierX = [del->dockPos isEqual:@"left"] || [del->dockPos isEqual:@"right"] ? ([del->dockPos isEqual:@"left"] ? 1 : -1) : 0;
    int multiplierY = [del->dockPos isEqual:@"bottom"] ? -1 : 0;
    CGPoint testPoint = CGPointMake(carbonPoint.x + multiplierX * CONTEXTDISTANCE, carbonPoint.y + multiplierY * CONTEXTDISTANCE); //check if there is an open AXMenu @ testPoint next to the mouseLocation (DockLeft +x, DockRight -x, DockBottom -y)
    NSDictionary* testInfo = [helperLib axInfo:[helperLib elementAtPoint:testPoint]];
//    CFRelease(testPoint);
    if ([testInfo[@"role"] isEqual:@"AXMenuItem"] || [testInfo[@"role"] isEqual:@"AXMenu"]) return YES;
    return NO;
}
+ (NSString*) getShowString: (NSString*) appBID {
    AppDelegate* del = [helperLib getApp];
    NSPoint pt = [NSEvent mouseLocation];
    int x = 0;
    int y = 0;
    BOOL isOnExtX = pt.x < 0 || (pt.x > del->primaryScreenWidth);
    BOOL isOnExtY = pt.y < 0 || (pt.y > del->primaryScreenHeight);
    BOOL isOnExt = isOnExtX || isOnExtY;
    if ([del->dockPos isEqual:@"bottom"]) {
        x = pt.x - del->dockWidth * 2;
        y = del->dockHeight;
        if (isOnExt) y = y + del->extendedOffsetY;
    } else if ([del->dockPos isEqual:@"left"]) {
        y = pt.y - del->dockHeight * 2;
        x = del->dockWidth;
        if (isOnExt) x = x - del->extScreenWidth;
    } else if ([del->dockPos isEqual:@"right"]) {
        y = pt.y - del->dockHeight * 2;
        x = ((pt.x <= del->primaryScreenWidth) ? del->primaryScreenWidth : del->primaryScreenWidth + del->extScreenWidth) - del->dockWidth;
    }
    if (!x && !y) { // accessiblity bug (#issue4 on github)  --show default AltTab location (centered)
        lastShowStr = [NSString stringWithFormat: @"showApp appBID \"%@\"", appBID];
        return lastShowStr;
    }
    lastShowStr = [NSString stringWithFormat: @"showApp appBID \"%@\" x %d y %d %@", appBID, x, y, [del->dockPos isEqual:@"right"] ? @"isRight true" : @""];
    return lastShowStr;
}
+ (void) AltTabShow: (NSString*) appBID {
    [helperLib runScript: [NSString stringWithFormat: @"tell application \"AltTab\" to %@", [app getShowString: appBID]]];
}
+ (void) AltTabHide {
    [helperLib runScript: @"tell application \"AltTab\" to hide"];
}
+ (float) maxDelay {return DELAY_MAX;}
+ (NSString*) getCurrentVersion {return [helperLib get: (NSString*) versionLink];}
+ (void) activateApp: (NSRunningApplication*) app {
    [app activateWithOptions:NSApplicationActivateIgnoringOtherApps];
    if ([[app localizedName] isEqual:@"Firefox"]) [helperLib runScript:@"tell application \"System Events\" to tell process \"Firefox\" to perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))"];
}
+ (NSString*) reopenDockStr: (BOOL) triggerEscape { // reopen / focus the dock w/ fn + a (after switching spaces)
    NSString* triggerEscapeStr = @"";
    if (triggerEscape) triggerEscapeStr = @"        delay 0.15\n\
        key code 53";
    return [NSString stringWithFormat:@"tell application \"System Events\"\n\
        key down 63\n\
        key code 0\n\
        key up 63\n%@\n\
    end tell", triggerEscapeStr];
}
@end

