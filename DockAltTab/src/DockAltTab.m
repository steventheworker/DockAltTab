//
//  DockAltTab.m
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import "DockAltTab.h"
#import "globals.h"
#import "helperLib.h"
#import "prefs.h"
#import "SupportedAltTabAttacher.h"

const float PREVIEW_INTERVAL_TICK_DELAY =  0.333; // 0.16666665; // 0.33333 / 2   seconds
const int ACTIVATION_MILLISECONDS = 30; //how long to wait to activate after [app unhide]
NSString* DATShowStringFormat = @"showApp appBID \"%@\" x %f y %f dockPos \"%@\""; // [NSString stringWithFormat: DATShowStringFormatappBID, x, y, dockPos];
pid_t dockPID;
pid_t AltTabPID;
int dockPos = DockBottom;
BOOL dockAutohide = NO;
CGRect dockRect;
id dockContextMenuClickee; //the dock separator element that was right clicked


int DATMode; // 1 = macos, 2 = ubuntu, 3 = windows (default value set in prefsWindowController)
int previewDelay = 0;int previewHideDelay = 0;
int thumbnailPreviewDelay = 0;BOOL thumbnailPreviewsEnabled = YES;int thumbnailPreviewTimeoutRef;id previewTarget;
NSMutableDictionary<NSString*, NSAppleScript*>* scripts;
float previewGutter = 0;
NSMutableDictionary* mousedownDict;
NSMutableDictionary* mousemoveDict;
NSTimer* previewIntervalTimer;
CGPoint cursorPos;
CGRect lastPreviewWinBounds;
int activationT = ACTIVATION_MILLISECONDS; //on spaceswitch: wait longer

int onScreenFinderWindows(void) { //returns 0 if app hidden (but then grabbing windows from appElement w/ AXUI should be accurate! but can we tell if they belong to the current space?)
    NSArray* wins = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    int count = 0;for (NSDictionary* win in wins) {
        if (![win[(id)kCGWindowOwnerName] isEqual: @"Finder"]) continue; //not finder
        if (![win[(id)kCGWindowIsOnscreen] boolValue]) continue; //not onscreen
        if ([win[(id)kCGWindowLayer] intValue] != 0) continue; // not regular window layer, could be desktop window, etc.
        count += 1;
    }
    return count;
}

void checkForDockChange(CGEventType type, id el, NSDictionary* elDict) {
    //live onchange of dock settings (dockPos, dockautohide)
    if ([elDict[@"PID"] intValue] == dockPID) {
        if ([elDict[@"subrole"] isEqual: @"AXSeparatorDockItem"] &&
            (type == kCGEventRightMouseDown || (type == kCGEventOtherMouseUp && [mousedownDict[@"subrole"] isEqual: @"AXSeparatorDockItem"]))
        ) { //cache the element so if a context menu item is selected we'll compare & know when a dock setting changes
            dockContextMenuClickee = el;
        }
    }
    if ([elDict[@"role"] isEqual: @"AXMenuItem"]) { //context menu item is being selected/triggered
        if (dockContextMenuClickee && type == kCGEventLeftMouseUp) {
            __block NSArray* children = [helperLib elementDict: dockContextMenuClickee : @{@"children": (id)kAXChildrenAttribute}][@"children"];
            if (children.count) { //there is a menu!
                children = [helperLib elementDict: children[0] : @{@"children": (id)kAXChildrenAttribute}][@"children"]; //menu items
                if (CFEqual((__bridge AXUIElementRef)children[0], (__bridge AXUIElementRef)el)) dockAutohide = !dockAutohide; //the first menu item is "Turn Hiding On/Off"
                else {
                    children = [helperLib elementDict: children[2] : @{@"children": (id)kAXChildrenAttribute}][@"children"]; //Position on screen items menu
                    children = [helperLib elementDict: children[0] : @{@"children": (id)kAXChildrenAttribute}][@"children"]; //Position on screen items menu children
                    if (CFEqual((__bridge AXUIElementRef)children[0], (__bridge AXUIElementRef)el)) dockPos = DockLeft;
                    if (CFEqual((__bridge AXUIElementRef)children[1], (__bridge AXUIElementRef)el)) dockPos = DockBottom;
                    if (CFEqual((__bridge AXUIElementRef)children[2], (__bridge AXUIElementRef)el)) dockPos = DockRight;
                }
            }
        }
    }
}

@implementation DockAltTab
+ (void) init {
    [self loadAltTabPID];
    if (!AltTabPID) [SupportedAltTabAttacher init: ^{[self loadAltTabPID];}];
    [self loadDockPID];
    [self loadDockRect];
    [self loadDockPos];
    [self loadDockAutohide];
    [self setMode: [prefs getIntPref: @"previewMode"]];
    [self setDelay: [prefs getFloatPref: @"previewDelay"] * 10 * 2];
    [self setHideDelay: [prefs getFloatPref: @"previewHideDelay"] * 10 * 2];
    [self setGutter: [prefs getFloatPref: @"previewGutter"]];
    [self setThumbnailPreviewDelay: [prefs getFloatPref: @"thumbnailPreviewDelay"] * 10 * 2];
    [self setThumbnailPreviewsEnabled: [prefs getBoolPref: @"thumbnailPreviewsEnabled"]];
    mousedownDict = [NSMutableDictionary dictionary];
    scripts = NSMutableDictionary.dictionary;
    scripts[@"thumbnailPreview"] = [NSAppleScript.alloc initWithSource: @"tell application \"AltTab\" to thumbnailPreview"];
    scripts[@"hide"] = [NSAppleScript.alloc initWithSource: @"tell application \"AltTab\" to hide"];
    scripts[@"newFinder"] = [NSAppleScript.alloc initWithSource: @"\n\
        tell application \"System Events\" to set uname to name of current user\n\
        tell application \"Finder\"\n\
        make new Finder window to folder \"Desktop\" of folder uname of folder \"Users\" of startup disk\n\
        activate\n\
        -- make new Finder window\n\
        -- set target of window 1 to folder \"Desktop\" of folder \"super\" of folder \"Users\" of startup disk\n\
        end tell\n\
    "];
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
+ (void) setDelay: (float) milliseconds {previewDelay = milliseconds;}
+ (void) setHideDelay: (float) milliseconds {previewHideDelay = milliseconds;}
+ (void) setThumbnailPreviewDelay: (float) milliseconds {thumbnailPreviewDelay = milliseconds;}
+ (void) setThumbnailPreviewsEnabled: (BOOL) tf {thumbnailPreviewsEnabled = tf;}
+ (void) setGutter: (float) gutter {previewGutter = gutter;}
+ (void) reconnectDock {
    [self loadDockPID];
    [self loadDockAutohide];
    [self loadDockPos];
    setTimeout(^{[self loadDockPID];}, 1000);
}
+ (BOOL) loadDockAutohide {dockAutohide = [helperLib dockAutohide];return dockAutohide;}
+ (int) loadDockPos {dockPos = [helperLib dockPos];return dockPos;}
+ (pid_t) loadDockPID {dockPID = [helperLib appWithBID: @"com.apple.dock"].processIdentifier;return dockPID;}
+ (pid_t) loadAltTabPID {AltTabPID = [helperLib appWithBID: @"com.steventheworker.alt-tab-macos"].processIdentifier;return AltTabPID;}
+ (CGRect) loadDockRect {dockRect = [helperLib dockRect];return dockRect;}
+ (NSMutableDictionary*) elDict: (id) el { //easy access to most referenced attributes
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
//    [helperLib activateApp: app.bundleURL : ^(NSRunningApplication* app, NSError* error) {
//        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            //        applescript is slow, DO NOT RUN HERE, figure out how to perform the axraise in objective-c
//            if ([[app localizedName] isEqual:@"Firefox"]) [helperLib applescriptAsync: @"tell application \"System Events\" to tell process \"Firefox\" to if (count of windows > 0) then perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))" : ^(NSString* response) {}];
//            if ([[app localizedName] isEqual:@"Firefox Developer Edition"]) [helperLib applescriptAsync: @"tell application \"System Events\" to tell process \"Firefox Developer Edition\" to if (count of windows > 0) then perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))" : ^(NSString* response) {}];
//        });
//    }];
        [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];
    //        applescript is slow, DO NOT RUN HERE, figure out how to perform the axraise in objective-c
//            if ([[app localizedName] isEqual:@"Firefox"]) [helperLib applescriptAsync: @"tell application \"System Events\" to tell process \"Firefox\" to if (count of windows > 0) then perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))" : ^(NSString* response) {}];
//            if ([[app localizedName] isEqual:@"Firefox Developer Edition"]) [helperLib applescriptAsync: @"tell application \"System Events\" to tell process \"Firefox Developer Edition\" to if (count of windows > 0) then perform action \"AXRaise\" of item 1 of (windows whose not(title is \"Picture-in-Picture\"))" : ^(NSString* response) {}];
    if ([app.localizedName hasPrefix: @"Firefox"]) [self firefoxActivated: app];
}
+ (void) unhideApp: (NSRunningApplication*) app {
    [app unhide];
    if ([app.localizedName hasPrefix: @"Firefox"]) [self firefoxActivated: app];
}
+ (void) firefoxActivated: (NSRunningApplication*) app {
    BOOL hasPIP = NO;
    id windowToFocusEl = nil;
    id appEl = (__bridge id)(AXUIElementCreateApplication(app.processIdentifier));
    NSArray* wins = [helperLib elementDict: appEl : @{@"wins": (id)kAXWindowsAttribute}][@"wins"];
    for (id win in wins) {
        NSString* title = [helperLib elementDict: win : @{@"title": (id)kAXTitleAttribute}][@"title"];
        if ([@"Picture-in-Picture" isEqual: title]) hasPIP = YES;
        else if (!windowToFocusEl) windowToFocusEl = win;
        if (hasPIP && windowToFocusEl) break;
    }
    if (hasPIP && windowToFocusEl) AXUIElementPerformAction((AXUIElementRef)windowToFocusEl, kAXRaiseAction);
}
+ (NSPoint) previewLocation: (CGPoint) cursorPos : (id) iconEl {
    NSDictionary* elDict = [helperLib elementDict: iconEl : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    NSPoint iconPt = [helperLib NSPointFromCGPoint: CGPointMake([elDict[@"pos"][@"x"] floatValue], [elDict[@"pos"][@"y"] floatValue])];
    NSSize iconSize = NSMakeSize([elDict[@"size"][@"width"] floatValue], [elDict[@"size"][@"height"] floatValue]);
    float x = iconPt.x;
    float y = iconPt.y;
    if (dockPos == DockBottom) {
        x = x + iconSize.width / 2;
        y -= 12;
    } else {
        if (dockPos == DockLeft) {
            x = iconPt.x + iconSize.width;
            x -= 13;
        } else if (dockPos == DockRight) x += 21.4;
        y = y - iconSize.height / 2;
    }
    return NSMakePoint(x, y);
}
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt {
    id iconEl = (DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"];
    NSPoint loc = [self previewLocation: pt : iconEl];
    float x = loc.x;float y = loc.y;
//    if (DockRight && endofscreenx - iconSize.width) {
//        
//    }
//    if (DockBottom && y < 30) {
//        
//    }
    if (dockPos == DockBottom) y += previewGutter;
    else x += dockPos == DockLeft ? previewGutter : -previewGutter;
    return [NSString stringWithFormat: DATShowStringFormat, appBID, x, y, dockPos == DockBottom ? @"bottom" : (dockPos == DockLeft ? @"left" : @"right")];
}
+ (void) showPreview: (NSString*) tarBID {
    id iconEl = (DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"];
    NSDictionary* elDict = [helperLib elementDict: iconEl : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    NSPoint iconPt = [helperLib NSPointFromCGPoint: CGPointMake([elDict[@"pos"][@"x"] floatValue], [elDict[@"pos"][@"y"] floatValue])];
    NSSize iconSize = NSMakeSize([elDict[@"size"][@"width"] floatValue], [elDict[@"size"][@"height"] floatValue]);
        
    CGPoint cachedCursorPos = cursorPos;
    setTimeout(^{
        id iconEl2 = (DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"];
        if (iconEl2 != iconEl) return;
        NSDictionary* elDict2 = [helperLib elementDict: iconEl : @{
            @"pos": (id)kAXPositionAttribute,
            @"size": (id)kAXSizeAttribute
        }];
        NSPoint iconPt2 = [helperLib NSPointFromCGPoint: CGPointMake([elDict2[@"pos"][@"x"] floatValue], [elDict2[@"pos"][@"y"] floatValue])];
        NSSize iconSize2 = NSMakeSize([elDict2[@"size"][@"width"] floatValue], [elDict2[@"size"][@"height"] floatValue]);
        float totDiff = fabs(iconPt.x - iconPt2.x) + fabs(iconPt.y - iconPt2.y) + fabs(iconSize.width - iconSize2.width) + fabs(iconSize.height - iconSize2.height);
        if (totDiff > 2 || (fabs(cursorPos.x - cachedCursorPos.x) + fabs(cursorPos.y - cachedCursorPos.y)) > 2) {
            return [self showPreview: tarBID];
        }
        [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to %@", [self getShowString: tarBID : cursorPos]]];
    }, 10);
}
+ (void) hidePreviewWindow {
    [scripts[@"hide"] executeAndReturnError: nil];
    previewTarget = nil;
}
+ (BOOL) isPreviewWindowShowing { /* is preview window (opened by DockAltTab) open? */
    NSArray* wins = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    for (NSDictionary* win in wins) {
        if ([win[(id)kCGWindowOwnerName] isEqual: @"AltTab"] && [win[(id)kCGWindowLayer] intValue] != 0) {//AltTab is open, but was it opened by DockAltTab? --//stop closing regular AltTab preview window on mousemove (since this is called every movement)
            AXUIElementRef iconEl = (__bridge AXUIElementRef) ((DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"]);
            CGRect winBounds = [helperLib rectWithDict: win[(id)kCGWindowBounds]];
            if (iconEl) lastPreviewWinBounds = winBounds; // cache this DAT preview window rect
            else {
                int equalCount = 0;
                if (winBounds.size.width == lastPreviewWinBounds.size.width) equalCount++;
                if (winBounds.size.height == lastPreviewWinBounds.size.height) equalCount++;
                if (winBounds.origin.x == lastPreviewWinBounds.origin.x) equalCount++;
                if (winBounds.origin.y == lastPreviewWinBounds.origin.y) equalCount++;
                if (equalCount >= 1) return YES; else return NO; // if none of these are the same, it's likely a regular AltTab window (todo: handle edgecase where AltTab has enough previews to trigger false positive)
            }
            return YES;
        }
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

/*
 events for each DATMode:  1:MacOS 2:Ubuntu 3:Windows
*/
/* DATMode:1      MacOS */
+ (BOOL) mousemoveMacOS : (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    [self mousemoveWindows: proxy : type : event : refcon : el : elDict];
    return YES;
}
+ (BOOL) mousedownMacOS : (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
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
            @"el": el,
        }];
        if ([self isPreviewWindowShowing]) [self hidePreviewWindow];
        NSLog(@"%d", previewWindowsCount);
        if (previewWindowsCount == 0 || ([tarApp.localizedName isEqual: @"Finder"] && !tarApp.isHidden && !onScreenFinderWindows())) {
            if ([tarApp.localizedName isEqual: @"Finder"]) {
                [scripts[@"newFinder"] executeAndReturnError: nil];
                return NO;
            }
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }
        return NO;
    }
    return YES;
}
+ (BOOL) mouseupMacOS : (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    if (type == kCGEventRightMouseUp) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        if ([mousedownDict[@"tarAppBID"] isNotEqualTo: tarApp.bundleIdentifier]) return NO; //don't do anything, mouse changed icons
        if ([mousedownDict[@"tarAppActive"] intValue] != (int) tarApp.active) return NO; //don't do anything, active app changed between mousedown/up
        
        int previewWindowsCount = [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue];
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
                return YES; //pass click through
        }
        
        if (type == kCGEventOtherMouseUp) return YES;
        if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
            if (tarApp.hidden) {
                [self unhideApp: tarApp];
                setTimeout(^{
                    [self activateApp: tarApp];
                    activationT = ACTIVATION_MILLISECONDS;
                }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
            } else [tarApp hide];
            return NO;
        } else {
            // check if the only window is a minimized window in the current space
            if (previewWindowsCount == 1 && 1 == [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countMinimizedWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue]) {
                [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", tarBID]];
            }
        }
        if (tarApp.active) [tarApp hide]; else [self activateApp: tarApp];
        return NO;
    }
    return YES;
}
/* DATMode:3      Windows */
+ (BOOL) mousemoveWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([elDict[@"PID"] intValue] == dockPID) {
        if ([elDict[@"running"] intValue]) { //check if should show?
            NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
            if ([mousemoveDict[@"tarBID"] isEqual: tarBID]) return YES;
            mousemoveDict = [NSMutableDictionary dictionaryWithDictionary: @{
                //            @"tarAppActive": @(tarApp.active),
                @"el": el,
                @"tarBID": tarBID
            }];
            if ([self isPreviewWindowShowing]) [self hidePreviewWindow];
            [self showPreview: tarBID];
        } else {
            mousemoveDict = [NSMutableDictionary dictionary];
            if ([self isPreviewWindowShowing]) [self hidePreviewWindow];
        }
    } else { //check if should hide
        if ([elDict[@"PID"] intValue] == AltTabPID) {
            if (self.isPreviewWindowShowing) {
                //thumbnail image
                if ([elDict[@"role"] isEqual: @"AXUnknown"] && (!previewTarget || !CFEqual((__bridge CFTypeRef)(previewTarget), (__bridge CFTypeRef)(el)))) {
                    if (thumbnailPreviewsEnabled) {
                        if (!thumbnailPreviewDelay || previewTarget) {
                            [scripts[@"thumbnailPreview"] executeAndReturnError: nil];
                            previewTarget = el;
                        } else {
                            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
                            thumbnailPreviewTimeoutRef = setTimeout(^{
                                [scripts[@"thumbnailPreview"] executeAndReturnError: nil];
                                previewTarget = el;
                            }, thumbnailPreviewDelay);
                        }
                    }
                }
                //thumbnail-peek
                if ([elDict[@"role"] isEqual: @"AXWindow"] && [elDict[@"subrole"] isEqual: @"AXUnknown"]) {
                    mousemoveDict = NSMutableDictionary.dictionary;
                    [self hidePreviewWindow];
                }
            }
        } else {
            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
            mousemoveDict = NSMutableDictionary.dictionary;
            if (self.isPreviewWindowShowing) [self hidePreviewWindow];
        }
    }
    return YES;
}
+ (BOOL) mousedownWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
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
            @"el": el
        }];
        if ([self isPreviewWindowShowing]) [self hidePreviewWindow];
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }
        return NO;
    }
    return YES;
}
+ (BOOL) mouseupWindows: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    if (type == kCGEventRightMouseUp) return YES;

    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        if ([mousedownDict[@"tarAppBID"] isNotEqualTo: tarApp.bundleIdentifier]) return NO; //don't do anything, mouse changed icons
        if ([mousedownDict[@"tarAppActive"] intValue] != (int) tarApp.active) return NO; //don't do anything, active app changed between mousedown/up
        
        int previewWindowsCount = [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue];
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }

        if (type == kCGEventOtherMouseUp) return YES;
        if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
            if ([tarApp.localizedName isEqual: @"Finder"]) {
                [scripts[@"newFinder"] executeAndReturnError: nil];
                return NO;
            }
            if (tarApp.hidden) {
                [self unhideApp: tarApp];
                setTimeout(^{
                    [self activateApp: tarApp];
                    activationT = ACTIVATION_MILLISECONDS;
                }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
            } else [tarApp hide];
            return NO;
        } else {
            // check if the only window is a minimized window in the current space
            if (previewWindowsCount == 1 && 1 == [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countMinimizedWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue]) {
                [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", tarBID]];
            }
        }
        if (tarApp.active) [tarApp hide]; else [self activateApp: tarApp];
        return NO;
    }
    return YES;
}
/* DATMode:2      Ubuntu */
+ (BOOL) mousedownUbuntu: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
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
            @"el": el
        }];
        if (/* type == kCGEventOtherMouseDown && */ [self isPreviewWindowShowing]) {
            mousedownDict[@"previewWasOpenOnDownFlag"] = @1;
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
+ (BOOL) mouseupUbuntu: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    if (type == kCGEventRightMouseUp) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        if ([mousedownDict[@"tarAppBID"] isNotEqualTo: tarApp.bundleIdentifier]) return NO; //don't do anything, mouse changed icons
        if ([mousedownDict[@"tarAppActive"] intValue] != (int) tarApp.active) return NO; //don't do anything, active app changed between mousedown/up
        if ([mousedownDict[@"previewWasOpenOnDownFlag"] intValue] /* && type == kCGEventOtherMouseUp */) return NO;
        
        int previewWindowsCount = [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue];
        BOOL enoughPreviewWindows = type == kCGEventOtherMouseUp ? previewWindowsCount >= 1 : previewWindowsCount >= 2;
        if (!previewWindowsCount) {
            if (![[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countWindows appBID \"%@\"", tarBID]] intValue])
            return YES; //pass click through
        }

        if (enoughPreviewWindows) {
            [self showPreview: tarBID];
        } else {
            if (type == kCGEventOtherMouseUp) return YES;
            if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
                if ([tarApp.localizedName isEqual: @"Finder"]) {
                    [scripts[@"newFinder"] executeAndReturnError: nil];
                    return NO;
                }
                if (tarApp.hidden) {
                    [self unhideApp: tarApp];
                    setTimeout(^{
                        [self activateApp: tarApp];
                        activationT = ACTIVATION_MILLISECONDS;
                    }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
                } else [tarApp hide];
                return NO;
            } else {
                // check if the only window is a minimized window in the current space
                    if (previewWindowsCount == 1 && 1 == [[helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to countMinimizedWindowsCurrentSpace appBID \"%@\"", tarBID]] intValue]) {
                        [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", tarBID]];
                    }
                }
                if (tarApp.active) [tarApp hide]; else [self activateApp: tarApp];
            }
            return NO;
        }
        return YES;
}
+ (BOOL) mousemoveUbuntu : (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([elDict[@"dockPID"] intValue] == dockPID) {
        if ([elDict[@"running"] intValue]) { //check if should show?
            NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
            if ([mousemoveDict[@"tarBID"] isEqual: tarBID]) return YES;
            mousemoveDict = [NSMutableDictionary dictionaryWithDictionary: @{
                //            @"tarAppActive": @(tarApp.active),
                @"el": el,
                @"tarBID": tarBID
            }];
        } else {
            mousemoveDict = [NSMutableDictionary dictionary];
        }
    } else { //check if should hide
        if ([elDict[@"PID"] intValue] == AltTabPID) {
            if (self.isPreviewWindowShowing) {
                //thumbnail image
                if ([elDict[@"role"] isEqual: @"AXUnknown"] && (!previewTarget || !CFEqual((__bridge CFTypeRef)(previewTarget), (__bridge CFTypeRef)(el)))) {
                    if (thumbnailPreviewsEnabled) {
                        if (!thumbnailPreviewDelay || previewTarget) {
                            [scripts[@"thumbnailPreview"] executeAndReturnError: nil];
                            previewTarget = el;
                        } else {
                            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
                            thumbnailPreviewTimeoutRef = setTimeout(^{
                                [scripts[@"thumbnailPreview"] executeAndReturnError: nil];
                                previewTarget = el;
                            }, thumbnailPreviewDelay);
                        }
                    }
                }
                //thumbnail-peek
                if ([elDict[@"role"] isEqual: @"AXWindow"] && [elDict[@"subrole"] isEqual: @"AXUnknown"]) {
                    mousemoveDict = NSMutableDictionary.dictionary;
                    [self hidePreviewWindow];
                }
            }
        } else {
            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
            mousemoveDict = NSMutableDictionary.dictionary;
        }
    }
    return YES;
}

/* events */
+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (CGPoint) pos {
//    NSLog(@"mm");
    cursorPos = pos;
    id el;
    if (DATMode == 2) {
        if (thumbnailPreviewsEnabled) { //for Ubuntu mode — only define el if thumbnailPreviewsEnabled
            AXUIElementRef focusedApp = AXUIElementCreateSystemWide();
            AXUIElementRef frontmostApp;
            AXUIElementCopyAttributeValue(focusedApp, kAXFocusedApplicationAttribute, (CFTypeRef*)&frontmostApp);
            NSString* appName = nil;
            if (frontmostApp) AXUIElementCopyAttributeValue(frontmostApp, kAXTitleAttribute, (void*)&appName);
            if ([appName isEqual: @"AltTab"]) el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
        }
        //else don't define el (powerpoint bug) ...the bug only happens if you read elementAtPoint while powerpoint is active! so if dock/AltTab/other has keyboard focus it's fine!
    } else el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];
    BOOL ret = YES;
    if (DATMode == 1) ret = [self mousemoveMacOS: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [self mousemoveUbuntu: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [self mousemoveWindows: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon {
    NSLog(@"md");
    id el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];
    
    checkForDockChange(type, el, elDict);
    
    BOOL ret = YES;
    if (DATMode == 1) ret = [self mousedownMacOS: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [self mousedownUbuntu: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [self mousedownWindows: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon {
    NSLog(@"mu");
    id el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];
    
    checkForDockChange(type, el, elDict);
    
    BOOL ret = YES;
    if (DATMode == 1) ret = [self mouseupMacOS: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [self mouseupUbuntu: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [self mouseupWindows: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (void) spaceChanged: (NSNotification*) note {
    activationT = 100;
    if (DATMode == 1) { //macos - rewshow on space switch
        
    }
}
@end
