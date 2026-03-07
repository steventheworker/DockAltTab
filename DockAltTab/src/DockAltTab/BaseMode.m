//
//  BaseMode.m
//  DockAltTab
//
//  Created by Steven G on 12/24/25.
//

#import "BaseMode.h"
#import "../globals.h"
#import "../helperLib.h"
#import "../DockAltTab.h"

NSRunningApplication* finder;
AXUIElementRef $finder;
id $finderWindowTarget;

@implementation BaseMode
+ (void) init {
    finder = [NSRunningApplication runningApplicationsWithBundleIdentifier: @"com.apple.finder"].firstObject;
    $finder = AXUIElementCreateApplication(finder.processIdentifier);
}

+ (void) activateApp: (NSRunningApplication*) app { // activateWithOptions (deprecated) fails (returning 0) after touch xcode ui (if debugger attached) ——fallback to applescript
    if ([app.bundleIdentifier isEqual: @"com.apple.finder"]) [self assignFinderTargetWindow: NO];
    
    BOOL success;
    if (@available(macOS 14.0, *)) { success = [app activateFromApplication: NSWorkspace.sharedWorkspace.frontmostApplication options: NSApplicationActivateIgnoringOtherApps]; }
    else { success = [app activateWithOptions: NSApplicationActivateIgnoringOtherApps]; }
    NSLog(@"activateApp success %d", success);
//    if (!success) [helperLib applescript: [NSString stringWithFormat: @"tell application id \"%@\" to activate", app.bundleIdentifier] :^(id res) { [self onAppActivate: app]; }]; else
    [self onAppActivate: app];
}

+ (void) onAppActivate: (NSRunningApplication*) app {
    if ([app.bundleIdentifier isEqual: @"com.apple.finder"]) [self onFinderActivate: app : NO];
    if ([app.localizedName hasPrefix: @"Firefox"]) [self firefoxActivated: app];
}

+ (void) unhideApp: (NSRunningApplication*) app {
    [app unhide];
    if ([app.localizedName hasPrefix: @"Firefox"]) [self firefoxActivated: app];
}

+ (void) demin: (NSRunningApplication*) app {
    if ([app.bundleIdentifier isEqual: @"com.apple.finder"]) [self assignFinderTargetWindow: YES];
    
    [self activateApp: app];
    [helperLib applescript: [NSString stringWithFormat: @"tell application \"AltTab\" to deminimizeFirstMinimizedWindowFromCurrentSpace appBID \"%@\"", app.bundleIdentifier] : ^(NSString* res) {
        appWindowCounts[@(app.processIdentifier)] = @{@"countWindows": @(getCount(@(app.processIdentifier), @"countWindows")), @"countWindowsCurrentSpace": @(getCount(@(app.processIdentifier), @"countWindowsCurrentSpace")), @"countMinimizedWindowsCurrentSpace": @0};
    }];
}

/*
    app handling
*/
+ (void) onFinderActivate: (NSRunningApplication*) app : (BOOL) assignTargetWindowFromMinimized {
    setTimeout(^{ [self ensureFinderFocusesNonDesktopWindow]; }, 0);
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

/*
    ensureFinderFocusesNonDesktopWindow
*/
+ (void) assignFinderTargetWindow: (BOOL) fromMinimized {
    $finderWindowTarget = nil;
    NSArray* wins = [helperLib elementDict: (__bridge id)$finder : @{@0: (id)kAXWindowsAttribute}][@0];
    for (int i = 0; i < wins.count; i++) {
        NSString* role; AXUIElementCopyAttributeValue((__bridge AXUIElementRef)wins[i], kAXRoleAttribute, (void*)&role);
        NSString* title; AXUIElementCopyAttributeValue((__bridge AXUIElementRef)wins[i], kAXTitleAttribute, (void*)&title); NSLog(@"finder win '%@'", title);
        if (fromMinimized) {
            NSNumber* min; AXUIElementCopyAttributeValue((__bridge AXUIElementRef)wins[i], kAXMinimizedAttribute, (void*)&min);
            if (!min.boolValue) continue;
        }
        if (![role isEqual: @"AXWindow"]) continue; // skip desktop window // todo: skip windows on other spaces
        $finderWindowTarget = wins[i];
        NSLog(@"tar: %@", title);
        break;
    }
}

+ (void) ensureFinderFocusesNonDesktopWindow { // desktop window = AXScrollArea, title==NULL
    id win = [helperLib elementDict: (__bridge id)$finder : @{@0: (id)kAXFocusedWindowAttribute}][@0];
    if (win) {
        NSString* role = [helperLib elementDict: win : @{@0: (id)kAXRoleAttribute}][@0];
        if (![role isEqual: @"AXWindow"] && $finderWindowTarget) {
            AXUIElementPerformAction((__bridge AXUIElementRef)$finderWindowTarget, kAXRaiseAction);
            $finderWindowTarget = nil;
        }
    } else {
        NSLog(@"no focused finder win... current front: %@", NSWorkspace.sharedWorkspace.frontmostApplication); // finder didn't activate!?
    }
}
@end
