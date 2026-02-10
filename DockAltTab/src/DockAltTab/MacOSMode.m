//
//  MacOSMode.m
//  DockAltTab
//
//  Created by Steven G on 12/24/25.
//

#import "MacOSMode.h"
#import "../DockAltTab.h"

@implementation MacOSMode
+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    [WindowsMode mousemove: proxy : type : event : refcon : el : elDict];
    return YES;
}

+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        if (type == kCGEventRightMouseDown) {
            if (DockAltTab.isPreviewWindowShowing) [DockAltTab hidePreviewWindow];
            return YES;
        }
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        int previewWindowsCount = getCount(@(tarApp.processIdentifier), @"countWindowsCurrentSpace");
        mousedownDict = [NSMutableDictionary dictionaryWithDictionary: @{
            @"tarAppActive": @(tarApp.active),
            @"el": el,
        }];
        if (DockAltTab.isPreviewWindowShowing) [DockAltTab hidePreviewWindow];
        if (previewWindowsCount || getCount(@(tarApp.processIdentifier), @"countWindows")) return NO;
    }
    return YES; //pass click through
}

+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([helperLib modifierKeys].count) return YES;
    if (type == kCGEventRightMouseUp) return YES;
    
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
        NSRunningApplication* tarApp = [helperLib appWithBID: tarBID];
        if ([mousedownDict[@"tarAppBID"] isNotEqualTo: tarApp.bundleIdentifier]) return NO; //don't do anything, mouse changed icons
        if ([mousedownDict[@"tarAppActive"] intValue] != (int) tarApp.active) return NO; //don't do anything, active app changed between mousedown/up
        
        int previewWindowsCount = getCount(@(tarApp.processIdentifier), @"countWindowsCurrentSpace");
        if (!previewWindowsCount) if (!getCount(@(tarApp.processIdentifier), @"countWindows")) return YES; //pass click through
        
        if (type == kCGEventOtherMouseUp) return YES; // pass click through
        if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
            if (tarApp.hidden) {
                [DockAltTab unhideApp: tarApp];
                setTimeout(^{
                    [DockAltTab activateApp: tarApp];
                    activationT = ACTIVATION_MILLISECONDS;
                }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
            } else {
                if ([tarApp.localizedName isEqual: @"Finder"] && !onScreenFinderWindows()) [helperLib applescriptWithScript: scripts[@"newFinder"] : ^(NSString* res) {}];
                else [tarApp hide];
            }
            return NO;
        } else {
            // check if the only window is a minimized window in the current space
            if (previewWindowsCount == 1 && 1 == getCount(@(tarApp.processIdentifier), @"countMinimizedWindowsCurrentSpace"))
                [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", tarBID] : ^(NSString* res) {}];
        }
        if (tarApp.active) [tarApp hide]; else [DockAltTab activateApp: tarApp];
        return NO;
    }
    if (keepDockShowing && dockAutohide && !CoreDockGetAutoHideEnabled()) setTimeout(^{if ([mousemoveDict[@"elDict"][@"PID"] intValue] != AltTabPID && !CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(YES);}, 333);
    return YES; // pass click through
}
@end
