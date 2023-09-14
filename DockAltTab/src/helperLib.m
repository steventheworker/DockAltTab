//
//  helperLib.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "helperLib.h"

NSMutableArray* eventTapRefs; // CFMachPortRef's (for restarting events / stopping)
NSMutableDictionary* eventMap; /* array of (BOOL) callbacks (NO = preventDefault) */
BOOL processEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
    BOOL callbackResult = YES; // yes, send the event (unless a callback returns NO (and nonnull))
    NSArray* callbacks = eventMap[[helperLib eventKeyWithEventType: type]];
    for (BOOL (^callback)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)
         in callbacks) if (callback(proxy, type, event, refcon) == NO) callbackResult = NO;
    return callbackResult;
}
/*
 * The function should return the (possibly modified) passed in event,
 * a newly constructed event, or NULL if the event is to be deleted.
 *
 * The CGEventRef passed into the callback is retained by the calling code, and is
 * released after the callback returns and the data is passed back to the event
 * system.  If a different event is returned by the callback function, then that
 * event will be released by the calling code along with the original event, after
 * the event data has been passed back to the event system.
 */
static CGEventRef eventTapCallback(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon) {
    return processEvent(proxy, type, event, refcon) ? event : nil;
}


@implementation helperLib
+ (void) activateWindow: (NSWindow*) window {
    [NSApp activateIgnoringOtherApps: YES];
    [window makeKeyAndOrderFront: nil];
}
+ (void) on: (NSString*) eventKey : (BOOL (^)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)) callback {
    if (!eventMap) eventMap = [NSMutableDictionary dictionary];
    if (!eventMap[eventKey]) eventMap[eventKey] = [NSMutableArray array];
    if (![eventMap[eventKey] count]) { //only create an eventTap if event type has no callbacks yet
        if (eventTapRefs.count == 0) eventTapRefs = [NSMutableArray array]; //must initialize mutableDict in a fn (compile time constants error), may as well do it here
        CFMachPortRef machPort = [self listenMask: [self maskWithEventKey: eventKey] : (CGEventTapCallBack) eventTapCallback];
        [eventTapRefs addObject: (__bridge id) machPort];
        [eventTapRefs addObject: [NSValue valueWithPointer: machPort]];


    }
    [eventMap[eventKey] addObject: callback];
}
+ (void) stopListening {
    //CFRelease() & remove from array
}
+ (void) startListening {
    //make new eventTap's & add to array
}
//+ (CGEventTapCallBack)eventTapCallback {return &eventTapCallback;} // expose it
+ (CFMachPortRef) listenMask : (CGEventMask) emask : (CGEventTapCallBack) handler {
    CFMachPortRef myEventTap;
    CFRunLoopSourceRef eventTapRLSrc;
    myEventTap = CGEventTapCreate (
      //kCGHIDEventTap, // Catch all events (Before system processes it)
        kCGSessionEventTap, // Catch all events for current user session (After system processes it)
      //kCGHeadInsertEventTap, // Append to beginning of EventTap list
        kCGTailAppendEventTap, // Append to end of EventTap list
        kCGEventTapOptionDefault, // handler returns nil to preventDefault
      //kCGEventTapOptionListenOnly, // handler returns nil to preventDefault
        emask,
        (CGEventTapCallBack) eventTapCallback,
//        handler,
        nil // We need no extra data in the callback
    );
    eventTapRLSrc = CFMachPortCreateRunLoopSource( //runloop source
        kCFAllocatorDefault,
        myEventTap,
        0
    );
    CFRunLoopAddSource(// Add the source to the current RunLoop
        CFRunLoopGetCurrent(),
        eventTapRLSrc,
        kCFRunLoopDefaultMode
    );
    CFRelease(eventTapRLSrc);
    return myEventTap;
}
+ (CGEventMask) maskWithEventKey: (NSString*) eventKey {
    if ([eventKey isEqual: @"mousedown"]) return CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown) | CGEventMaskBit(kCGEventOtherMouseDown);
    if ([eventKey isEqual: @"mouseup"]) return CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp) | CGEventMaskBit(kCGEventOtherMouseUp);
    return kCGEventMaskForAllEvents;
}
+ (NSString*) eventKeyWithEventType: (CGEventType) type {
    switch(type) {
        case kCGEventLeftMouseDown:
        case kCGEventRightMouseDown:
        case kCGEventOtherMouseDown:
            return @"mousedown";break;
        case kCGEventLeftMouseUp:
        case kCGEventRightMouseUp:
        case kCGEventOtherMouseUp:
            return @"mouseup";break;
        case kCGEventNull:
        case kCGEventMouseMoved:
        case kCGEventLeftMouseDragged:
        case kCGEventRightMouseDragged:
        case kCGEventKeyDown:
        case kCGEventKeyUp:
        case kCGEventFlagsChanged:
        case kCGEventScrollWheel:
        case kCGEventTabletPointer:
        case kCGEventTabletProximity:
        case kCGEventOtherMouseDragged:
        case kCGEventTapDisabledByTimeout:
        case kCGEventTapDisabledByUserInput:
            return @"default";break;
    }
}

/* https://stackoverflow.com/questions/15305845/how-can-a-mac-gui-app-relaunch-itself-without-using-sparkle */
+ (void) restartApp {
    // Get the path to the current running app executable
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* executablePath = [mainBundle executablePath];
    const char* execPtr = [executablePath UTF8String];

#if ATEXIT_HANDLING_NEEDED
    // Get the pid of the parent process
    pid_t originalParentPid = getpid();

    // Fork a child process
    pid_t pid = fork();
    if (pid != 0) // Parent process - exit so atexit() is called
    {
        exit(0);
    }

    // Now in the child process

    // Wait for the parent to die. When it does, the parent pid changes.
    while (getppid() == originalParentPid)
    {
        usleep(250 * 1000); // Wait .25 second
    }
#endif

    // Do the relaunch
    execl(execPtr, execPtr, NULL);
}
@end
