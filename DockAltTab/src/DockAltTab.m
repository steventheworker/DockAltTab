//
//  DockAltTab.m
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import "DockAltTab.h"
#import "../AppDelegate.h"
#import "helperLib.h"

pid_t dockPID;

@implementation DockAltTab
+ (void) init {
    [self loadDockPid];
}
+ (void) loadDockPid {
    NSArray* runningApps = [[NSWorkspace sharedWorkspace] runningApplications];
    for (NSRunningApplication* app in runningApps) if ([app.bundleIdentifier isEqual:@"com.apple.dock"]) dockPID = app.processIdentifier;
}
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
+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if (type == kCGEventRightMouseDown || type == kCGEventOtherMouseDown) return YES;
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        return NO;
    }
    return YES;
}
+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict {
    if (type == kCGEventRightMouseUp || type == kCGEventOtherMouseUp) return YES;
    if ([elDict[@"PID"] intValue] == dockPID && [elDict[@"running"] intValue]) {
        NSArray* children = [helperLib elementDict: el : @{@"children": (id)kAXChildrenAttribute}][@"children"];
        if (children.count) return YES; //children on an icon === icon menu is showing
        return NO;
    }
    return YES;
}
@end
