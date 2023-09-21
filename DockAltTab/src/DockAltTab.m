//
//  DockAltTab.m
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import "DockAltTab.h"
#import "globals.h"
#import "helperLib.h"

const float PREVIEW_INTERVAL_TICK_DELAY =  0.333; // 0.16666665; // 0.33333 / 2   seconds
NSString* DATShowStringFormat = @"showApp appBID \"%@\" x %d y %d dockPos \"%@\""; // [NSString stringWithFormat: DATShowStringFormatappBID, x, y, dockPos];
pid_t dockPID;
NSString* dockPos = @"bottom";
BOOL dockAutohide = NO;
CGRect dockRect;

int DATMode; // 1 = macos, 2 = ubuntu, 3 = windows (default value set in prefsWindowController)
NSMutableDictionary* mousedownDict;
NSTimer* previewIntervalTimer;
CGPoint cursorPos;

@implementation DockAltTab
+ (void) init {
    [self loadDockPID];
    [self loadDockRect];
    [self loadDockPos];
    [self loadDockAutohide];
    mousedownDict = [NSMutableDictionary dictionary];
}
+ (void) setMode: (int) mode {
    DATMode = mode;
    [self stopPreviewInterval];
    switch(mode) {
        case 1:break;
        case 2:break;
        case 3:
            [self startPreviewInterval];
            break;
    }
}
+ (BOOL) loadDockAutohide {dockAutohide = [helperLib dockAutohide];return dockAutohide;}
+ (NSString*) loadDockPos {dockPos = [helperLib dockPos];return dockPos;}
+ (pid_t) loadDockPID {dockPID = [helperLib appWithBID: @"com.apple.dock"].processIdentifier;return dockPID;}
+ (CGRect) loadDockRect {dockRect = [helperLib dockRect];return dockRect;}
+ (NSMutableDictionary*) elDict: (AXUIElementRef) el { //easy access to most referenced attributes
    return [NSMutableDictionary dictionaryWithDictionary: [helperLib elementDict: el : @{
        @"title": (id)kAXTitleAttribute,
        @"role": (id)kAXRoleAttribute,
        @"subrole": (id)kAXSubroleAttribute,
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute,
        @"running": (id)kAXIsApplicationRunningAttribute,
        @"PID": (id)kAXPIDAttribute
    }]];
}
+ (void) activateApp: (NSRunningApplication*) app {
    [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];
    if ([[app localizedName] isEqual:@"Firefox"]) [helperLib applescript: @"tell application \"System Events\" to tell process \"Firefox\" to perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))"];
    if ([[app localizedName] isEqual:@"Firefox Developer Edition"]) [helperLib applescript: @"tell application \"System Events\" to tell process \"Firefox Developer Edition\" to perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))"];
}
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt {
    int x = 0;
    int y = 0;
    NSScreen* primaryScreen = [helperLib primaryScreen];
    NSScreen* extScreen = [helperLib screenAtPt: pt];
    BOOL isOnExt = primaryScreen != extScreen;
    
    NSDictionary* elDict = [helperLib elementDict: (__bridge AXUIElementRef) mousedownDict[@"el"] : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    if ([dockPos isEqual: @"bottom"]) {
        x = [elDict[@"pos"][@"x"] floatValue] + [elDict[@"size"][@"width"] floatValue] / 2;
        y = [elDict[@"size"][@"width"] floatValue] - 1;
        if (isOnExt) y = y + extScreen.frame.origin.y;
    } else {
        int mouseScreenHeight = (pt.x <= primaryScreen.frame.size.width) ? primaryScreen.frame.size.height : extScreen.frame.size.height;
        y = mouseScreenHeight - [elDict[@"pos"][@"y"] floatValue]; // left & right have the same y
        if ([dockPos isEqual: @"left"]) {
            x = [elDict[@"size"][@"width"] floatValue] - 1;
            if (isOnExt) x = x - extScreen.frame.size.width;
        } else if ([dockPos isEqual: @"right"]) {
            x = (([elDict[@"pos"][@"x"] floatValue] <= primaryScreen.frame.size.width) ? primaryScreen.frame.size.width : primaryScreen.frame.size.width + extScreen.frame.size.width) - [elDict[@"size"][@"width"] floatValue] + 7;
            x += 1;
        }
    }
    return [NSString stringWithFormat: DATShowStringFormat, appBID, x, y, dockPos];
}
+ (void) hidePreviewWindow {[helperLib applescript: @"tell application \"AltTab\" to hide"];}
+ (BOOL) isPreviewWindowShowing {
    CFArrayRef wins = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    long int winCount = CFArrayGetCount(wins);
    for (int i = 0; i < winCount; i++) {
        NSDictionary* win = CFArrayGetValueAtIndex(wins, i);
        if ([win[(id)kCGWindowOwnerName] isEqual: @"AltTab"] && [win[(id)kCGWindowLayer] intValue] != 0) return YES;
    }
    return NO;
}
+ (void) startPreviewInterval {previewIntervalTimer = [NSTimer scheduledTimerWithTimeInterval: PREVIEW_INTERVAL_TICK_DELAY target: self selector: NSSelectorFromString(@"timerTick:") userInfo: nil repeats: YES];}
+ (void) stopPreviewInterval {[previewIntervalTimer invalidate];}
+ (void)timerTick: (NSTimer*) arg {
//    AXUIElementRef el = [helperLib elementAtPoint: cursorPos];
//    NSMutableDictionary* elDict = [self elDict: el];
//    NSLog(@"%@", [helperLib dictionaryStringOneLine: elDict : YES]);
}

/* events */
+ (BOOL) mousemoveWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    return YES;
}
+ (BOOL) mousedownWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        return NO;
    }
    return YES;
}
+ (BOOL) mouseupWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        return NO;
    }
    return YES;
}
+ (BOOL) mousedownUbuntu: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
     
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        if (type == kCGEventRightMouseDown) {
            if ([self isPreviewWindowShowing]) [self hidePreviewWindow];
            return YES;
        }
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        int previewWindowsCount =  [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        mousedownDict = [NSMutableDictionary dictionaryWithDictionary: @{
            @"tarAppActive": @(tarApp.active),
            @"el": (__bridge id _Nonnull)(el)
        }];
        if (type == kCGEventOtherMouseDown && [self isPreviewWindowShowing]) {
            mousedownDict[@"previewWasOpenOnMiddleBtnFlag"] = @1;
            [self hidePreviewWindow];
        }
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }
        return NO;
    }
    return YES;
}
+ (BOOL) mouseupUbuntu: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    if (type == kCGEventRightMouseUp) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        if ([mousedownDict[@"tarAppBID"] isNotEqualTo: tarApp.bundleIdentifier]) return NO; //don't do anything, mouse changed icons
        if ([mousedownDict[@"tarAppActive"] intValue] != (int) tarApp.active) return NO; //don't do anything, active app changed between mousedown/up
        if ([mousedownDict[@"previewWasOpenOnMiddleBtnFlag"] intValue] && type == kCGEventOtherMouseUp) return NO;
        
        int previewWindowsCount = [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue];
        BOOL enoughPreviewWindows = type == kCGEventOtherMouseUp ? previewWindowsCount >= 1 : previewWindowsCount >= 2;
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }

        if (enoughPreviewWindows) {
            [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to %@", [self getShowString: tarBID : cursorPos]]];
        } else {
            if (type == kCGEventOtherMouseUp) return YES;
            if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
                if (tarApp.hidden) {
                    [tarApp unhide];
                    setTimeout(^{[self activateApp: tarApp];}, 30); //activating too quickly after unhiding is what switches spaces!
                } else [tarApp hide];
                return NO;
            }
            if (tarApp.active) [tarApp hide]; else [self activateApp: tarApp];
        }
        return NO;
    }
    return YES;
}
+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) pos {
    cursorPos = pos;
    return DATMode == 2 ? [self mousemoveUbuntu: proxy : type : event : refcon : el : elDict] :
                        [self mousemoveWindows: proxy : type : event : refcon : el : elDict];
}
+ (BOOL) mousemoveUbuntu : (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {return YES;}
+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    return DATMode == 2 ? [self mousedownUbuntu: proxy : type : event : refcon : el : elDict] :
                        [self mousedownWindows: proxy : type : event : refcon : el : elDict];
}
+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    return DATMode == 2 ? [self mouseupUbuntu: proxy : type : event : refcon : el : elDict] :
                        [self mouseupWindows: proxy : type : event : refcon : el : elDict];
}
+ (void) spaceChanged: (NSNotification*) note {
    lastSpeedPatrolled = @"";
}
@end
