//
//  UbuntuMode.m
//  DockAltTab
//
//  Created by Steven G on 12/24/25.
//

#import "UbuntuMode.h"
#import "../DockAltTab.h"

@implementation UbuntuMode
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
            @"el": el
        }];
        if (/* type == kCGEventOtherMouseDown && */ DockAltTab.isPreviewWindowShowing) {
            mousedownDict[@"previewWasOpenOnDownFlag"] = @1;
            [DockAltTab hidePreviewWindow];
        }
        if (!previewWindowsCount) if (!getCount(@(tarApp.processIdentifier), @"countWindows")) return YES; //pass click through
        return NO;
    }
    return YES;
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
        if ([mousedownDict[@"previewWasOpenOnDownFlag"] intValue] /* && type == kCGEventOtherMouseUp */) return NO;
        
        int previewWindowsCount = getCount(@(tarApp.processIdentifier), @"countWindowsCurrentSpace");
        BOOL enoughPreviewWindows = type == kCGEventOtherMouseUp ? previewWindowsCount >= 1 : previewWindowsCount >= 2;
        if (!previewWindowsCount) if (!getCount(@(tarApp.processIdentifier), @"countWindows")) return YES; //pass click through

        if (enoughPreviewWindows) {
            [DockAltTab showPreview: tarBID];
        } else {
            if (type == kCGEventOtherMouseUp) return YES;
            if (!previewWindowsCount) { //probably has windows on another space, prevent space switch but still activate app
                if (tarApp.hidden) {
                    [DockAltTab unhideApp: tarApp];
                    setTimeout(^{
                        [DockAltTab activateApp: tarApp];
                        activationT = ACTIVATION_MILLISECONDS;
                    }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
                } else {
                    if ([tarApp.localizedName isEqual: @"Finder"]) [helperLib applescriptWithScript: scripts[@"newFinder"] : ^(NSString* res) {}];
                    else [tarApp hide];
                }
                return NO;
            } else {
                // check if the only window is a minimized window in the current space
                if (previewWindowsCount == 1 && 1 == getCount(@(tarApp.processIdentifier), @"countMinimizedWindowsCurrentSpace"))
                    [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", tarBID] : ^(NSString* res) {}];
            }
            if (tarApp.active) [tarApp hide]; else [DockAltTab activateApp: tarApp];
        }
        return NO;
    }
    if (keepDockShowing && dockAutohide && !CoreDockGetAutoHideEnabled()) setTimeout(^{if ([mousemoveDict[@"elDict"][@"PID"] intValue] != AltTabPID && !CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(YES);}, 333);
    /* handle mousemoveless */ if (!thumbnailPreviewsEnabled && isDockActive && !previewTarget) { isDockActive = NO;[DockAltTab onDockBecameInactive]; } // counts on mousedownDict to sync (and see ondockbecameactive)... here we give onDockBecameInactive (but only if not actively previewing)
    return YES;
}

+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([elDict[@"dockPID"] intValue] == dockPID) {
        if ([elDict[@"running"] intValue]) { //check if should show?
            NSString* tarBID = [[NSBundle bundleWithURL: [helperLib elementDict: el : @{@"url": (id)kAXURLAttribute}][@"url"]] bundleIdentifier];
            if ([mousemoveDict[@"tarBID"] isEqual: tarBID]) return YES;
            mousemoveDict = [NSMutableDictionary dictionaryWithDictionary: @{
                //            @"tarAppActive": @(tarApp.active),
                @"el": el,
                @"tarBID": tarBID,
                @"elDict": elDict
            }];
        } else {
            mousemoveDict = [NSMutableDictionary dictionary];
        }
    } else { //check if should hide
        if ([elDict[@"PID"] intValue] == AltTabPID) {
            if (DockAltTab.isPreviewWindowShowing) {
                //thumbnail image
                if ([elDict[@"role"] isEqual: @"AXUnknown"] && (!previewTarget || !CFEqual((__bridge CFTypeRef)(previewTarget), (__bridge CFTypeRef)(el)))) {
                    if (thumbnailPreviewsEnabled) {
                        if (!thumbnailPreviewDelay || previewTarget) {
                            [helperLib applescriptWithScript: scripts[@"thumbnailPreview"] : ^(NSString* res) {}];
                            previewTarget = el;
                        } else {
                            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
                            thumbnailPreviewTimeoutRef = setTimeout(^{
                                [helperLib applescriptWithScript: scripts[@"thumbnailPreview"] : ^(NSString* res) {}];
                                previewTarget = el;
                            }, thumbnailPreviewDelay);
                        }
                    }
                }
                
                if (keepDockShowing && dockAutohide && CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(NO);
                
                //thumbnail-peek
                if ([elDict[@"role"] isEqual: @"AXWindow"] && [elDict[@"subrole"] isEqual: @"AXUnknown"]) {
                    mousemoveDict = NSMutableDictionary.dictionary;
                    [DockAltTab hidePreviewWindow];
                    if (keepDockShowing && dockAutohide && !CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(YES);
                }
            }
        } else {
            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
            mousemoveDict = NSMutableDictionary.dictionary;
        }
    }
    return YES;
}
@end
