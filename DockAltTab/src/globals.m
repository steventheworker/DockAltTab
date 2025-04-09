//
//  globals.m    -    globals.c  (error https://stackoverflow.com/questions/25999754/error-message-could-not-build-module-foundation (bryan 's answer))
//  DockAltTab
//
//  Created by Steven G on 10/21/22.
//

#include "globals.h"
#import <Foundation/Foundation.h>

int timeoutIndex = 1; //start at 1. (since clarTimeout returns 0)
NSMutableDictionary<NSNumber*, NSNumber*>* timeouts;

int setTimeout(void(^cb)(void), int delay) {
    if (!timeouts) timeouts = NSMutableDictionary.dictionary;
    NSNumber* timeoutIndexRef = @(timeoutIndex);
    timeouts[timeoutIndexRef] = @1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * (delay)), dispatch_get_main_queue(), ^{
        if (!timeouts[timeoutIndexRef].intValue) return;
        cb();
        [timeouts removeObjectForKey: timeoutIndexRef];
    });
    return timeoutIndex++;
}
int clearTimeout(int i) {
    NSNumber* timeoutIndex = @(i);
    if ([timeouts[timeoutIndex] intValue]) [timeouts removeObjectForKey: timeoutIndex];
    return 0;
}

void throw(NSString* message, ...) {
    va_list args;
    va_start(args, message);
    NSString* formattedString = [[NSString alloc] initWithFormat: message arguments: args];
    va_end(args);

    NSLog(@"_________");
    NSLog(@"||throw|| %@", formattedString);
    NSLog(@"---------");
    //cause a crash (hack so we can trace the execution tree)
//    NSLog(@"%@");
    AXUIElementRef a = nil;setTimeout(^{CFRelease(a);}, 1000);
//    [NSApp terminate: nil];
//    setTimeout(^{[NSApp terminate: nil];}, 1);
//    NSCAssert(NO, message);
//    @throw [NSException exceptionWithName: @"CustomException" reason: message userInfo: nil];
}
BOOL within(int ms, NSDate* t0, NSDate* t1) {
    NSTimeInterval dt = [t0 timeIntervalSinceDate: t1] * 1000; // Convert to milliseconds
    return fabs(dt) <= ms; // Use fabs to handle negative time intervals
}

// hideRunningApp / unhideRunningApp
const int HIDEUNHIDE_POLL_T_MS = 10; //milliseconds between poll(s)
const int HIDEUNHIDE_MAX_TRIES = 24; //amount of times we poll before giving up on hiding this app
void hideRunningApp(NSRunningApplication* app, void(^cb)(void)) {
    if (app.isHidden) cb(); //already hidden
    if (app.activationPolicy != NSApplicationActivationPolicyRegular) { //apllication IS agent
        if (NSRunningApplication.currentApplication.processIdentifier == app.processIdentifier) {
            [NSApp hide: nil]; //CAN hide agent app (but only for THIS app (the owner app)
            app = (NSRunningApplication*)NSApp;
        } else return throw(@"can't hide agent app's unless it's your own app");
    } else [app hide];
    __block int attempts = 0;
    __block void (^checkup)(void) = ^{
        if (app.isHidden) return cb();
        if (attempts >= HIDEUNHIDE_MAX_TRIES) return throw(@"%@ exceeded max tries @ hideRunningApp", app);
        attempts += 1;
        setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS);
    };
    setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS); //start checking up
}
void unhideRunningApp(NSRunningApplication* app, void(^cb)(void)) {
    if (!app.isHidden) cb(); //already visible (may not be frontmost though)
    if (app.activationPolicy != NSApplicationActivationPolicyRegular) { //apllication IS agent
        if (NSRunningApplication.currentApplication.processIdentifier == app.processIdentifier) {
            [NSApp unhide: nil]; //CAN unhide agent app (but only for THIS app (the owner app)
            app = (NSRunningApplication*)NSApp;
        } else return throw(@"can't unhide agent app's unless it's your own app");
    } else [app unhide];
    __block int attempts = 0;
    __block void (^checkup)(void) = ^{
        if (!app.isHidden) return cb();
        if (attempts >= HIDEUNHIDE_MAX_TRIES) return throw(@"%@ exceeded max tries @ unhideRunningApp", app);
        attempts += 1;
        setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS);
    };
    setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS); //start checking up
}
void activateRunningApp(NSRunningApplication* app, void(^cb)(void)) {
    if (app.isActive) cb(); //already visible (may not be frontmost though)
    if (app.activationPolicy != NSApplicationActivationPolicyRegular) { //apllication IS agent
        if (NSRunningApplication.currentApplication.processIdentifier == app.processIdentifier) {
            [NSApp activateIgnoringOtherApps: YES]; //CAN unhide agent app (but only for THIS app (the owner app)
            app = (NSRunningApplication*)NSApp;
        } else return throw(@"can't unhide agent app's unless it's your own app");
    } else [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];;
    __block int attempts = 0;
    __block void (^checkup)(void) = ^{
        if (app.isActive) return cb();
        if (attempts >= HIDEUNHIDE_MAX_TRIES) return throw(@"%@ exceeded max tries @ activateRunningApp", app);
        attempts += 1;
        setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS);
    };
    setTimeout(^{checkup();}, HIDEUNHIDE_POLL_T_MS); //start checking up
}
