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

//define
const int CONTEXTDISTANCE = 150; //dock testPoint/contextmenu's approx. distance from pointer
const int DOCK_OFFSET = 5; //5 pixels


@implementation app
//initialize app variables (onLaunch)
+ (void) initVars {
    NSLog(@"%@", @"running app :)\n-------------------------------------------------------------------");
    AppDelegate* del = [helperLib getApp];
    //functional
    [del bindScreens]; //load screen data
    del->appDisplayed = @"";
    del->dockPos = [helperLib getDockPosition];
    del->dockPID = [helperLib getPID:@"com.apple.dock"]; //todo: refresh dockPID every x or so?
    del->AltTabPID = [helperLib getPID:@"com.steventheworker.alt-tab-macos"];
    if (del->AltTabPID == 0) {
        del->unsupportedAltTab = YES;
        del->AltTabPID = [helperLib getPID:@"com.lwouis.alt-tab-macos"];
    }
    del->finderPID = [helperLib getPID:@"com.apple.Finder"];
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
    del->isLockDockContentsChecked = CFPreferencesGetAppBooleanValue( CFSTR("contents-immutable"), CFSTR("com.apple.dock"), &valid);
    del->isLockDockSizeChecked = CFPreferencesGetAppBooleanValue( CFSTR("size-immutable"), CFSTR("com.apple.dock"), &valid);
    del->isLockDockPositionChecked = CFPreferencesGetAppBooleanValue( CFSTR("position-immutable"), CFSTR("com.apple.dock"), &valid);
    //DockAltTab settings
    del->isClickToggleChecked = ![[NSUserDefaults standardUserDefaults] boolForKey:@"isClickToggleChecked"]; // (!) default true
    del->previewDelay = ((int) [[NSUserDefaults standardUserDefaults] integerForKey:@"previewDelay"]);
    [app syncUI];
}
+ (void) syncUI {
    AppDelegate* del = [helperLib getApp];
    del->lockDockContentsCheckbox.state = del->isLockDockContentsChecked;
    del->lockDockSizeCheckbox.state = del->isLockDockSizeChecked;
    del->lockDockPositionCheckbox.state = del->isLockDockPositionChecked;
    del->clickToggleCheckBox.state = del->isClickToggleChecked;
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
+ (void) AltTabShow: (NSString*) appBID {
    NSDictionary *error = nil;
    AppDelegate* del = [helperLib getApp];
    NSPoint pt = [NSEvent mouseLocation];
    int x = 0;
    int y = 0;
    if ([del->dockPos isEqual:@"bottom"]) {
        x = pt.x - del->dockWidth * 2;
        y = del->dockHeight;
    } else if ([del->dockPos isEqual:@"left"]) {
        y = pt.y - del->dockHeight * 2;
        x = del->dockWidth;
    } else if ([del->dockPos isEqual:@"right"]) {
        y = pt.y - del->dockHeight * 2;
        x = ((pt.x <= del->primaryScreenWidth) ? del->primaryScreenWidth : del->primaryScreenWidth + del->extScreenWidth) - del->dockWidth;
    }
    NSString* scriptTxt = [NSString stringWithFormat: @"tell application \"AltTab\" to showApp appBID \"%@\" x %d y %d %@", appBID, x, y, [del->dockPos isEqual:@"right"] ? @"isRight true" : @""];
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptTxt];
    [script executeAndReturnError:&error];
    if (error) NSLog(@"run error: %@", error);
}
+ (void) AltTabHide {
    NSDictionary *error = nil;
    NSString* scriptTxt = @"tell application \"AltTab\" to hide";
    NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptTxt];
    [script executeAndReturnError:&error];
    if (error) NSLog(@"run error: %@", error);
}
+ (float) maxDelay {return DELAY_MAX;}
+ (NSString*) getCurrentVersion {return [helperLib get: (NSString*) versionLink];}
@end

