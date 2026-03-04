//
//  WindowsMode.m
//  DockAltTab
//
//  Created by Steven G on 12/24/25.
//

#import "WindowsMode.h"
#import "../DockAltTab.h"
#import "../helperLib.h"

@implementation WindowsMode
/*
    mousemove
*/
+ (BOOL) mousemove: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict {
    if ([elDict[@"PID"] intValue] == dockPID) {
        if ([elDict[@"running"] intValue]) { //check if should show?
            NSBundle* bundle = [NSBundle bundleWithURL: [helperLib elementDict: el : @{@0: (id)kAXURLAttribute}][@0]];
            if (!bundle) return YES; // dock item bundle url is stale, user should re-add to dock
            NSString* tarBID = bundle ? bundle.bundleIdentifier : @"";
            if ([mousemoveDict[@"tarBID"] isEqual: tarBID]) return YES;
            mousemoveDict = [NSMutableDictionary dictionaryWithDictionary: @{
                //            @"tarAppActive": @(tarApp.active),
                @"el": el,
                @"tarBID": tarBID,
                @"elDict": elDict
            }];
            [DockAltTab showPreview: tarBID];
        } else {
            mousemoveDict = [NSMutableDictionary dictionary];
            if (DockAltTab.isPreviewWindowShowing) [DockAltTab hidePreviewWindow];
        }
    } else { //check if should hide
        if ([elDict[@"PID"] intValue] == AltTabPID) {
            //roles for DAT window elements: AXScrollArea, AXStaticText, AXButton, thumbnail (AXUnknown) subrole="" for all
            if (DockAltTab.isPreviewWindowShowing) {
                BOOL isPreviewPanel = NO;
                BOOL isPreviewWindow = [elDict[@"role"] isEqual: @"AXWindow"] && [elDict[@"subrole"] isEqual: @"AXUnknown"];
                if (isPreviewWindow) {
                    isPreviewWindow = ((NSArray*)[helperLib elementDict: el : @{@0: (id)kAXChildrenAttribute}][@0]).count > 0; //check if it's actually the preview panel (preview window / thumbnail panel are both role=AXWindow, subrole=AXUnknown) but preview panel children=None
                    isPreviewPanel = !isPreviewWindow;
                }
                if (thumbnailPreviewsEnabled) {
                    BOOL somethingChanged = previewTarget && (/*DockAltTab.countAltTabWindows == 1 || */!CFEqual((__bridge CFTypeRef)(previewTarget), (__bridge CFTypeRef)(el))); // we should have 2 windows if previewTarget != nil
                    if (([@[@"AXUnknown", @"AXScrollArea", @"AXStaticText", @"AXButton"] containsObject: elDict[@"role"]] || isPreviewWindow)
                        && (!previewTarget || somethingChanged)) {
                        if (!thumbnailPreviewDelay || previewTarget) {
                            previewTarget = el;
                            [helperLib applescriptWithScript: scripts[@"thumbnailPreview"] : ^(NSString* res) { }];
                        } else {
                            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
                            thumbnailPreviewTimeoutRef = setTimeout(^{
                                if (previewTarget && CFEqual((__bridge CFTypeRef)(previewTarget), (__bridge CFTypeRef)(el))) return;
                                previewTarget = el;
                                [helperLib applescriptWithScript: scripts[@"thumbnailPreview"] : ^(NSString* res) { }];
                            }, thumbnailPreviewDelay);
                        }
                    }
                    if (previewTarget && isPreviewPanel) {
                        NSLog(@"hidePreviewWindow");
                        mousemoveDict = NSMutableDictionary.dictionary;
                        [DockAltTab hidePreviewWindow];
                    }
                }
                if (keepDockShowing && dockAutohide && CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(NO);
            }
        } else {
            if (keepDockShowing && dockAutohide && !CoreDockGetAutoHideEnabled()) setTimeout(^{if ([mousemoveDict[@"elDict"][@"PID"] intValue] != AltTabPID && !CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(YES);}, 333);
            if (thumbnailPreviewTimeoutRef) thumbnailPreviewTimeoutRef = clearTimeout(thumbnailPreviewTimeoutRef);
            mousemoveDict = NSMutableDictionary.dictionary;
            if (DockAltTab.isPreviewWindowShowing) [DockAltTab hidePreviewWindow];
        }
    }
    return YES;
}

/*
    mousedown
*/
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

/*
    mouseup
*/
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
                [self unhideApp: tarApp];
                setTimeout(^{
                    [self activateApp: tarApp];
                    activationT = ACTIVATION_MILLISECONDS;
                }, activationT); //activating too quickly (w/ ignoringOtherApps) after unhiding is what switches spaces!
            } else {
                if ([tarApp.localizedName isEqual: @"Finder"] && !onScreenFinderWindows()) [helperLib applescriptWithScript: scripts[@"newFinder"] : ^(NSString* res) {}];
                else [tarApp hide];
            }
            return NO;
        } else {
            if (previewWindowsCount == 1 && 1 == getCount(@(tarApp.processIdentifier), @"countMinimizedWindowsCurrentSpace")) { // check if the only window is a minimized window in the current space
                [self demin: tarApp];
                return NO;
            }
        }
        if (tarApp.active) [tarApp hide]; else [self activateApp: tarApp];
        return NO;
    }
    if (keepDockShowing && dockAutohide && !CoreDockGetAutoHideEnabled()) setTimeout(^{if ([mousemoveDict[@"elDict"][@"PID"] intValue] != AltTabPID && !CoreDockGetAutoHideEnabled()) CoreDockSetAutoHideEnabled(YES);}, 333);
    return YES; // pass click through
}
@end
