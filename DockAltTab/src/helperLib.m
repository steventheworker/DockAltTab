//
//  helperLib.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "helperLib.h"

AXUIElementRef systemWideElement;

/* events */
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
/* AXUIElement  */
+ (void) setSystemWideEl: (AXUIElementRef) el {systemWideElement = el;} //used in elementAtPoint, etc.
+ (AXUIElementRef) elementAtPoint: (CGPoint) pt {
    AXUIElementRef element = NULL;
    AXError result = AXUIElementCopyElementAtPosition(systemWideElement, pt.x, pt.y, &element);
    if (result != kAXErrorSuccess) NSLog(@"elementAtPoint failed");
    return element;
}
+ (NSDictionary*) elementDict: (AXUIElementRef) el : (NSDictionary*) attributeDict {
    NSMutableDictionary* dict = [NSMutableDictionary dictionary];
    for (NSString* attributeName in attributeDict) {
        id attribute = attributeDict[attributeName];
/* kAXAllowedValuesAttribute kAXAMPMFieldAttribute kAXCancelButtonAttribute kAXChildrenAttribute kAXCloseButtonAttribute
 kAXColumnTitleAttribute kAXContentsAttribute kAXDayFieldAttribute kAXDefaultButtonAttribute kAXDescriptionAttribute
 kAXEnabledAttribute kAXFocusedAttribute kAXGrowAreaAttribute kAXHeaderAttribute kAXHelpAttribute
 kAXHourFieldAttribute kAXIncrementorAttribute kAXInsertionPointLineNumberAttribute kAXMainAttribute kAXMaxValueAttribute
 kAXMinimizeButtonAttribute kAXMinimizedAttribute kAXMinuteFieldAttribute kAXMinValueAttribute kAXModalAttribute
 kAXMonthFieldAttribute kAXNumberOfCharactersAttribute kAXOrientationAttribute kAXParentAttribute kAXPositionAttribute
 kAXProxyAttribute kAXRoleAttribute kAXRoleDescriptionAttribute kAXSecondFieldAttribute kAXSelectedChildrenAttribute
 kAXSelectedTextAttribute kAXSelectedTextRangeAttribute kAXSelectedTextRangesAttribute kAXSharedCharacterRangeAttribute kAXSharedTextUIElementsAttribute
 kAXSizeAttribute kAXSubroleAttribute kAXTitleAttribute kAXToolbarButtonAttribute kAXTopLevelUIElementAttribute
 kAXURLAttribute kAXValueAttribute kAXValueDescriptionAttribute kAXValueIncrementAttribute kAXVisibleCharacterRangeAttribute
 kAXVisibleChildrenAttribute kAXVisibleColumnsAttribute kAXWindowAttribute kAXYearFieldAttribute kAXZoomButtonAttribute   */
        if (attribute == (id)kAXAllowedValuesAttribute) {
            // Handle kAXAllowedValuesAttribute
        } else if (attribute == (id)kAXAMPMFieldAttribute) {
            // Handle kAXAMPMFieldAttribute
        } else if (attribute == (id)kAXCancelButtonAttribute) {
            // Handle kAXCancelButtonAttribute
        } else if (attribute == (id)kAXChildrenAttribute) {
            // Handle kAXChildrenAttribute
        } else if (attribute == (id)kAXCloseButtonAttribute) {
            // Handle kAXCloseButtonAttribute
        } else if (attribute == (id)kAXColumnTitleAttribute) {
            // Handle kAXColumnTitleAttribute
        } else if (attribute == (id)kAXContentsAttribute) {
            // Handle kAXContentsAttribute
        } else if (attribute == (id)kAXDayFieldAttribute) {
            // Handle kAXDayFieldAttribute
        } else if (attribute == (id)kAXDefaultButtonAttribute) {
            // Handle kAXDefaultButtonAttribute
        } else if (attribute == (id)kAXDescriptionAttribute) {
            // Handle kAXDescriptionAttribute
        } else if (attribute == (id)kAXEnabledAttribute) {
            // Handle kAXEnabledAttribute
        } else if (attribute == (id)kAXFocusedAttribute) {
            // Handle kAXFocusedAttribute
        } else if (attribute == (id)kAXGrowAreaAttribute) {
            // Handle kAXGrowAreaAttribute
        } else if (attribute == (id)kAXHeaderAttribute) {
            // Handle kAXHeaderAttribute
        } else if (attribute == (id)kAXHelpAttribute) {
            // Handle kAXHelpAttribute
        } else if (attribute == (id)kAXHourFieldAttribute) {
            // Handle kAXHourFieldAttribute
        } else if (attribute == (id)kAXIncrementorAttribute) {
            // Handle kAXIncrementorAttribute
        } else if (attribute == (id)kAXInsertionPointLineNumberAttribute) {
            // Handle kAXInsertionPointLineNumberAttribute
        } else if (attribute == (id)kAXMainAttribute) {
            // Handle kAXMainAttribute
        } else if (attribute == (id)kAXMaxValueAttribute) {
            // Handle kAXMaxValueAttribute
        } else if (attribute == (id)kAXMinimizeButtonAttribute) {
            // Handle kAXMinimizeButtonAttribute
        } else if (attribute == (id)kAXMinimizedAttribute) {
            // Handle kAXMinimizedAttribute
        } else if (attribute == (id)kAXMinuteFieldAttribute) {
            // Handle kAXMinuteFieldAttribute
        } else if (attribute == (id)kAXMinValueAttribute) {
            // Handle kAXMinValueAttribute
        } else if (attribute == (id)kAXModalAttribute) {
            // Handle kAXModalAttribute
        } else if (attribute == (id)kAXMonthFieldAttribute) {
            // Handle kAXMonthFieldAttribute
        } else if (attribute == (id)kAXNumberOfCharactersAttribute) {
            // Handle kAXNumberOfCharactersAttribute
        } else if (attribute == (id)kAXOrientationAttribute) {
            // Handle kAXOrientationAttribute
        } else if (attribute == (id)kAXParentAttribute) {
            // Handle kAXParentAttribute
        } else if (attribute == (id)kAXPositionAttribute) {
            // Handle kAXPositionAttribute
        } else if (attribute == (id)kAXProxyAttribute) {
            // Handle kAXProxyAttribute
        } else if (attribute == (id)kAXRoleAttribute) {
            // Handle kAXRoleAttribute
        } else if (attribute == (id)kAXRoleDescriptionAttribute) {
            // Handle kAXRoleDescriptionAttribute
        } else if (attribute == (id)kAXSecondFieldAttribute) {
            // Handle kAXSecondFieldAttribute
        } else if (attribute == (id)kAXSelectedChildrenAttribute) {
            // Handle kAXSelectedChildrenAttribute
        } else if (attribute == (id)kAXSelectedTextAttribute) {
            // Handle kAXSelectedTextAttribute
        } else if (attribute == (id)kAXSelectedTextRangeAttribute) {
            // Handle kAXSelectedTextRangeAttribute
        } else if (attribute == (id)kAXSelectedTextRangesAttribute) {
            // Handle kAXSelectedTextRangesAttribute
        } else if (attribute == (id)kAXSharedCharacterRangeAttribute) {
            // Handle kAXSharedCharacterRangeAttribute
        } else if (attribute == (id)kAXSharedTextUIElementsAttribute) {
            // Handle kAXSharedTextUIElementsAttribute
        } else if (attribute == (id)kAXSizeAttribute) {
            // Handle kAXSizeAttribute
        } else if (attribute == (id)kAXSubroleAttribute) {
            CFTypeRef subroleValue;
            AXError result = AXUIElementCopyAttributeValue(el, kAXSubroleAttribute, &subroleValue);
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString *subrole = (__bridge NSString *)subroleValue;
                dict[attributeName] = subrole;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXTitleAttribute) {
            NSString *axTitle = nil;
            AXError result = AXUIElementCopyAttributeValue(el, kAXTitleAttribute, (void *)&axTitle);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = axTitle;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXToolbarButtonAttribute) {
            // Handle kAXToolbarButtonAttribute
        } else if (attribute == (id)kAXTopLevelUIElementAttribute) {
            // Handle kAXTopLevelUIElementAttribute
        } else if (attribute == (id)kAXURLAttribute) {
            // Handle kAXURLAttribute
        } else if (attribute == (id)kAXValueAttribute) {
            // Handle kAXValueAttribute
        } else if (attribute == (id)kAXValueDescriptionAttribute) {
            // Handle kAXValueDescriptionAttribute
        } else if (attribute == (id)kAXValueIncrementAttribute) {
            // Handle kAXValueIncrementAttribute
        } else if (attribute == (id)kAXVisibleCharacterRangeAttribute) {
            // Handle kAXVisibleCharacterRangeAttribute
        } else if (attribute == (id)kAXVisibleChildrenAttribute) {
            // Handle kAXVisibleChildrenAttribute
        } else if (attribute == (id)kAXVisibleColumnsAttribute) {
            // Handle kAXVisibleColumnsAttribute
        } else if (attribute == (id)kAXWindowAttribute) {
            // Handle kAXWindowAttribute
        } else if (attribute == (id)kAXYearFieldAttribute) {
            // Handle kAXYearFieldAttribute
        } else if (attribute == (id)kAXZoomButtonAttribute) {
            // Handle kAXZoomButtonAttribute
        } else {
            // Default case when attribute is not matched
            dict[attributeName] = @"";
            NSLog(@"attribute %@ DNE", attributeName);
        }
    }
    return dict;
}

/* events */
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

/* misc. */
+ (void) activateWindow: (NSWindow*) window {
    [NSApp activateIgnoringOtherApps: YES];
    [window makeKeyAndOrderFront: nil];
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
