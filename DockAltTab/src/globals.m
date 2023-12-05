//
//  globals.m    -    globals.c  (error https://stackoverflow.com/questions/25999754/error-message-could-not-build-module-foundation (bryan 's answer))
//  DockAltTab
//
//  Created by Steven G on 10/21/22.
//

#include "globals.h"
#import <Foundation/Foundation.h>

int timeoutIndex = 0;
NSMutableDictionary* timeouts;

int setTimeout(void(^cb)(void), int delay) {
    if (!timeoutIndex) timeouts = [NSMutableDictionary dictionary];
    NSString* timeoutIndexStr = [NSString stringWithFormat: @"%d", timeoutIndex];
    timeouts[timeoutIndexStr] = @1;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * (delay)), dispatch_get_main_queue(), ^{
        if ([timeouts[timeoutIndexStr] intValue]) {
            cb();
            clearTimeout(timeoutIndex);
        }
    });
    return timeoutIndex++;
}
void clearTimeout(int i) {
    NSString* timeoutIndexStr = [NSString stringWithFormat: @"%d", i];
    if ([timeouts[timeoutIndexStr] intValue]) [timeouts removeObjectForKey: timeoutIndexStr];
}

void throw(NSString* message, ...) {
    va_list args;
    va_start(args, message);
    NSString* formattedString = [[NSString alloc] initWithFormat: message arguments: args];
    va_end(args);

    NSLog(@"_________");
    NSLog(@"||throw|| %@", formattedString);
    NSLog(@"---------");
    [NSApp terminate: nil];
//    setTimeout(^{[NSApp terminate: nil];}, 1);
//    NSCAssert(NO, message);
//    @throw [NSException exceptionWithName: @"CustomException" reason: message userInfo: nil];
}
