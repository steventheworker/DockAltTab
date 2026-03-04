//
//  DockAltTab.m
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import "DockAltTab.h"
#import "helperLib.h"

const float PREVIEW_INTERVAL_TICK_DELAY =  0.333; // 0.16666665; // 0.33333 / 2   seconds
const int ACTIVATION_MILLISECONDS = 30; //how long to wait to activate after [app unhide]
NSString* DATShowStringFormat = @"showApp appBID \"%@\" x %f y %f dockPos \"%@\""; // [NSString stringWithFormat: DATShowStringFormat, appBID, x, y, dockPos];
NSString* DATRepositionStringFormat = @"repositionThumbnails {%f, %f}"; // [NSString stringWithFormat: DATRepositionStringFormat, x, y];
pid_t dockPID;
pid_t AltTabPID;
int dockPos = DockBottom;
BOOL dockAutohide = NO;
BOOL dockMagnification = NO;
int dockMagnificationSize = 16; // magnification off 'largesize' = 16
CGRect dockRect; CGRect baselineDockRect;
id dockContextMenuClickee; //the dock separator element that was right clicked


int DATMode; // 1 = macos, 2 = ubuntu, 3 = windows (default value set in prefsWindowController)
int previewDelay = 0;int previewHideDelay = 0;
int thumbnailPreviewDelay = 0;BOOL thumbnailPreviewsEnabled = YES;int thumbnailPreviewTimeoutRef;id previewTarget;
BOOL keepDockShowing = YES;
NSMutableDictionary<NSString*, NSAppleScript*>* scripts;
float previewGutter = 0;
NSMutableDictionary* mousedownDict;
NSMutableDictionary* mousemoveDict;
NSTimer* previewIntervalTimer;
CGPoint cursorPos;
CGRect lastPreviewWinBounds;
int activationT = ACTIVATION_MILLISECONDS; //on spaceswitch: wait longer
NSMutableDictionary<NSNumber*, NSDictionary<NSString*, NSNumber*>*>* appWindowCounts;
BOOL isDockActive = NO;
NSArray* CGWindowList;
id showIcon;
NSRect showIconRect;

int getCount(NSNumber* pid, NSString* key) { return (appWindowCounts[pid] ?: (NSDictionary<NSString*, NSNumber*>*)@{})[key].intValue; }

int onScreenFinderWindows(void) { //returns 0 if app hidden (but then grabbing windows from appElement w/ AXUI should be accurate! but can we tell if they belong to the current space?)
    CGWindowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    int count = 0;for (NSDictionary* win in CGWindowList) {
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
                if (CFEqual((__bridge AXUIElementRef)children[1], (__bridge AXUIElementRef)el)) dockMagnification = !dockMagnification;
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
    [self loadDockAutohide]; [self loadDockMagnification]; [self loadDockMagnificationSize];
    [self loadDockPos]; baselineDockRect = self.currentDockRect;
    [self setMode: [prefs getIntPref: @"previewMode"]];
    [self setDelay: [prefs getFloatPref: @"previewDelay"] * 10 * 2];
    [self setHideDelay: [prefs getFloatPref: @"previewHideDelay"] * 10 * 2];
    [self setGutter: [prefs getFloatPref: @"previewGutter"]];
    [self setThumbnailPreviewDelay: [prefs getFloatPref: @"thumbnailPreviewDelay"] * 10 * 2];
    [self setThumbnailPreviewsEnabled: [prefs getBoolPref: @"thumbnailPreviewsEnabled"]];
    [self setkeepDockShowing: [prefs getBoolPref: @"keepDockShowing"]];
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
    scripts[@"countAllWindowStats"] = [NSAppleScript.alloc initWithSource: @"tell application \"AltTab\" to countAllWindowStats"];
    appWindowCounts = NSMutableDictionary.dictionary;
    [self syncCounts: ^{}];
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
+ (void) setkeepDockShowing: (BOOL) tf {keepDockShowing = tf;}
+ (void) reconnectDock {
    [self loadDockPID];
    [self loadDockAutohide]; [self loadDockMagnification]; [self loadDockMagnificationSize];
    [self loadDockPos];
    setTimeout(^{[self loadDockPID];}, 1000);
}
+ (BOOL) loadDockAutohide {dockAutohide = helperLib.dockAutohide;return dockAutohide;}
+ (BOOL) loadDockMagnification {dockMagnification = helperLib.dockMagnification;return dockMagnification;}
+ (int) loadDockMagnificationSize {dockMagnificationSize = helperLib.dockMagnificationSize;return dockMagnificationSize;}
+ (int) loadDockPos {dockPos = [helperLib dockPos];return dockPos;}
+ (pid_t) loadDockPID {dockPID = [helperLib appWithBID: @"com.apple.dock"].processIdentifier;return dockPID;}
+ (pid_t) loadAltTabPID {AltTabPID = [helperLib appWithBID: @"com.steventheworker.alt-tab-macos"].processIdentifier;return AltTabPID;}
+ (CGRect) loadDockRect {/* dockRect = [helperLib dockRect]; */return dockRect;}
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
+ (NSPoint) previewLocation: (CGPoint) cursorPos : (id) iconEl {
    NSDictionary* elDict = [helperLib elementDict: iconEl : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    NSPoint iconPt = [helperLib NSPointFromCGPoint: CGPointMake([elDict[@"pos"][@"x"] floatValue], [elDict[@"pos"][@"y"] floatValue])];
    NSSize iconSize = NSMakeSize([elDict[@"size"][@"width"] floatValue], [elDict[@"size"][@"height"] floatValue]);
        
    float x = iconPt.x;
    float y = iconPt.y;
    
    // magnification seems to leave 1 unchanged (bottom = height, left/right = width)
    if (isDockActive && dockMagnification) {
        if (dockPos == DockBottom) {
            iconSize = NSMakeSize(iconSize.width, iconSize.height + (dockMagnificationSize - iconSize.height));
            x = x + iconSize.width / 2;
            y = iconSize.height + 2.7 / (((float)dockMagnificationSize/128) * ((float)dockMagnificationSize/128));
        } else {
            iconSize = NSMakeSize(iconSize.width + (dockMagnificationSize - iconSize.width), iconSize.height);
            if (dockPos == DockRight) { x += 35 * (((float)dockMagnificationSize / 128)); }
            else if (dockPos == DockLeft) { x = [elDict[@"size"][@"width"] floatValue] - 17 * (((float)dockMagnificationSize / 128)); }
            y -= iconSize.height / 2;
        }
    } else {
        if (dockPos == DockBottom) {
            x = x + iconSize.width / 2;
            y -= 12;
        } else if (dockPos == DockLeft) {
            x += iconSize.width;
            x -= 5;
            y = y - iconSize.height / 2;
        } else if (dockPos == DockRight) { x += 12; y = y - iconSize.height / 2; }
    }
    return NSMakePoint(x, y);
}
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt {
    id iconEl = (DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"];
    NSPoint loc = [self previewLocation: pt : iconEl];
    float x = loc.x;float y = loc.y;
    if (dockPos == DockBottom) y += previewGutter;
    else x += dockPos == DockLeft ? previewGutter : -previewGutter;
    return [NSString stringWithFormat: DATShowStringFormat, appBID, x, y, dockPos == DockBottom ? @"bottom" : (dockPos == DockLeft ? @"left" : @"right")];
}
+ (NSString*) getRepositionString: (CGPoint) pt {
    NSPoint loc = [self previewLocation: pt : showIcon];
    float x = loc.x;float y = loc.y;
    if (dockPos == DockBottom) y += previewGutter;
    else x += dockPos == DockLeft ? previewGutter : -previewGutter;
    return [NSString stringWithFormat: DATRepositionStringFormat, x, y];
}
+ (void) showPreview: (NSString*) tarBID {
    id iconEl = showIcon = (DATMode == 2) ? mousedownDict[@"el"] : mousemoveDict[@"el"];
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
        [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to %@", [self getShowString: tarBID : cursorPos]] : ^(NSString* res) {}];
        showIconRect = NSMakeRect(iconPt2.x, iconPt2.y, iconSize2.width, iconSize2.height);
    }, 10);
}
+ (void) hidePreviewWindow {
    if (previewTarget) previewTarget = nil; if (!showIcon) return;
    [helperLib applescriptWithScript: scripts[@"hide"] : ^(NSString* res) {}];
    showIcon = nil; showIconRect = NSZeroRect;
}
+ (BOOL) isPreviewWindowShowing { /* is preview window (opened by DockAltTab) open? */
    CGWindowList = CFBridgingRelease(CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID));
    for (NSDictionary* win in CGWindowList) {
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
+ (CGRect) currentDockRect {
    CGRect rect = CGRectZero;
    CoreDockGetRect(&rect); // rect.size.width = 0 w/ autohide (no matter if shown/hidden). also doesn't change with magnification.
    float magSize = dockMagnificationSize + 25;
    if (dockPos == DockBottom) rect.size.height = magSize; else rect.size.width = magSize;
    return rect;
}
+ (BOOL) magnificationActive {
    if (!dockMagnification || !isDockActive) return NO;
    NSDictionary* elDict = [helperLib elementDict: showIcon : @{
        @"pos": (id)kAXPositionAttribute,
        @"size": (id)kAXSizeAttribute
    }];
    NSPoint iconPt = [helperLib NSPointFromCGPoint: CGPointMake([elDict[@"pos"][@"x"] floatValue], [elDict[@"pos"][@"y"] floatValue])];
    NSSize iconSize = NSMakeSize([elDict[@"size"][@"width"] floatValue], [elDict[@"size"][@"height"] floatValue]);
    showIconRect = CGRectMake(iconPt.x, iconPt.y, iconSize.width, iconSize.height);
    if (dockPos == DockRight && cursorPos.x - 5 > showIconRect.origin.x) return YES;
    if (dockPos == DockLeft && cursorPos.x < showIconRect.origin.x + showIconRect.size.width + 5) return YES;
    NSPoint nscursorPos = [helperLib NSPointFromCGPoint: cursorPos];
    if (dockPos == DockBottom && nscursorPos.y < showIconRect.origin.y + 5) return YES;
    return NO;
}
+ (int) countAltTabWindows {
    int count = 0;
    for (NSDictionary* win in CGWindowList) {
        if ([win[(id)kCGWindowOwnerName] isEqual: @"AltTab"] && [win[(id)kCGWindowLayer] intValue] != 0) count++;
    }
    return count;
}
+ (void) startPreviewInterval { /*previewIntervalTimer = [NSTimer scheduledTimerWithTimeInterval: PREVIEW_INTERVAL_TICK_DELAY target: self selector: NSSelectorFromString(@"timerTick:") userInfo: nil repeats: YES];*/}
+ (void) stopPreviewInterval { [previewIntervalTimer invalidate]; }
+ (void)timerTick: (NSTimer*) arg {
//    AXUIElementRef el = [helperLib elementAtPoint: cursorPos];
//    NSMutableDictionary* elDict = [self elDict: el];
//    NSLog(@"%@", [helperLib dictionaryStringOneLine: elDict : YES]);
}
+ (void) onDockBecameActive {
    [self handleIsDockActiveChanged: YES];
    [self syncCountsWhileDockActive];
}
NSDate* lastSyncT;
+ (void) syncCounts : (void(^)(void)) cb {
    NSLog(@"syncCounts");
    [helperLib applescriptWithScript: scripts[@"countAllWindowStats"] : ^(id res) {
        appWindowCounts = NSMutableDictionary.dictionary;
        for (NSDictionary* record in res) appWindowCounts[record[@"pPID"]] = @{
                @"countWindows": record[@"cWin"] ?: @0,
                @"countWindowsCurrentSpace": record[@"cCur"] ?: @0,
                @"countMinimizedWindowsCurrentSpace": record[@"cMin"] ?: @0
            };
        cb();
    }];
    lastSyncT = NSDate.date;
}
+ (void) syncCountsWhileDockActive {
    if (!isDockActive) return;
    setTimeout(^{
        if (isDockActive && [NSDate.date timeIntervalSinceDate: lastSyncT] >= 1)
            [self syncCounts: ^{
//                if (isDockActive) setTimeout(^{ if (isDockActive) [self syncCountsWhileDockActive]; }, 1000);
            }];
    }, 1000);
}
+ (void) onDockBecameInactive {
    [self handleIsDockActiveChanged: NO];
}
+ (void) handleIsDockActiveChanged: (BOOL) _isDockActive {
    NSLog(@"dock %@", _isDockActive ? @"active" : @"inactive");
    isDockActive = _isDockActive;
    if (dockMagnification) setTimeout(^{ // wait for mousemove to load CGWindowList
        if (self.countAltTabWindows && (!dockAutohide || keepDockShowing)) { // reposition to account for loss of icon zoom/magnification
            [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to %@", [self getRepositionString: cursorPos]] : ^(NSString* res) {}];
        }
    }, 150);
}
+ (BOOL) recomputeIsDockActive: (int) cursorPID {
    BOOL onDockPID = cursorPID == dockPID; if (onDockPID) return YES;
    BOOL onAltTabPID = cursorPID == AltTabPID;
    if (onAltTabPID) {
        if (self.magnificationActive) return YES;
    }
    return NO;
}

/*
 events for each DATMode:  1:MacOS 2:Ubuntu 3:Windows
*/
/* DATMode:1      MacOS */
/* DATMode:3      Windows */
/* DATMode:2      Ubuntu */

/* events */
+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (CGPoint) pos {
//    NSLog(@"mm");
    cursorPos = pos;
    id el;
    if (DATMode == 2) {
        if (thumbnailPreviewsEnabled) { //for Ubuntu mode — only define el if thumbnailPreviewsEnabled
            AXUIElementRef frontmostApp;
            AXUIElementCopyAttributeValue(systemWideEl, kAXFocusedApplicationAttribute, (CFTypeRef*)&frontmostApp);
            NSString* appName = nil;
            if (frontmostApp) AXUIElementCopyAttributeValue(frontmostApp, kAXTitleAttribute, (void*)&appName);
            if ([appName isEqual: @"AltTab"]) el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
        } else { el = [mousedownDict[@"expired"] boolValue] ? nil : mousedownDict[@"el"]; mousedownDict[@"expired"] = @YES; }
        //else don't define el (powerpoint bug) ...the bug only happens if you read elementAtPoint while powerpoint is active! so if dock/AltTab/other has keyboard focus it's fine!
    } else el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];

    if ([self recomputeIsDockActive: [elDict[@"PID"] intValue]]) {
        if (!isDockActive) { isDockActive = YES; [self onDockBecameActive]; }
    } else if (isDockActive) { isDockActive = NO; [self onDockBecameInactive]; }
    
    BOOL ret = YES;
    if (DATMode == 1) ret = [MacOSMode mousemove: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [UbuntuMode mousemove: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [WindowsMode mousemove: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon {
    NSLog(@"md");
    id el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];
    
    checkForDockChange(type, el, elDict);
    
    BOOL ret = YES;
    if (DATMode == 1) ret = [MacOSMode mousedown: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [UbuntuMode mousedown: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [WindowsMode mousedown: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon {
    NSLog(@"mu");
    id el = [helperLib elementAtPoint: [helperLib normalizePointForDockGap: cursorPos : dockPos]];
    NSMutableDictionary* elDict = [DockAltTab elDict: el];
    
    checkForDockChange(type, el, elDict);
    
    BOOL ret = YES;
    if (DATMode == 1) ret = [MacOSMode mouseup: proxy : type : event : refcon : el : elDict];
    if (DATMode == 2) ret = [UbuntuMode mouseup: proxy : type : event : refcon : el : elDict];
    if (DATMode == 3) ret = [WindowsMode mouseup: proxy : type : event : refcon : el : elDict];
    return ret;
}
+ (void) spaceChanged: (NSNotification*) note {
    activationT = 100;
    if (DATMode == 1) { //macos - rewshow on space switch
        
    }
}
@end
