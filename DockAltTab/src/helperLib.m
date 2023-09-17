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
         kAXColumnHeaderUIElementsAttribute kAXColumnsAttribute kAXColumnTitleAttribute kAXContentsAttribute kAXDayFieldAttribute
         kAXDecrementButtonAttribute kAXDefaultButtonAttribute kAXDescriptionAttribute kAXDisclosedByRowAttribute kAXDisclosedRowsAttribute
         kAXDisclosingAttribute kAXDocumentAttribute kAXEditedAttribute kAXEnabledAttribute kAXExpandedAttribute
         kAXFilenameAttribute kAXFocusedApplicationAttribute kAXFocusedAttribute kAXFocusedUIElemenAttribute kAXFocusedWindowAttribute
         kAXFrontmostAttribute kAXGrowAreaAttribute kAXHeaderAttribute kAXHelpAttribute kAXHourFieldAttribute
         kAXIncrementorAttribute kAXInsertionPointLineNumberAttribute kAXMainAttribute kAXMaxValueAttribute kAXMinimizeButtonAttribute
         kAXMinimizedAttribute kAXMinuteFieldAttribute kAXMinValueAttribute kAXModalAttribute kAXMonthFieldAttribute
         kAXNumberOfCharactersAttribute kAXOrientationAttribute kAXParentAttribute kAXPositionAttribute kAXProxyAttribute
         kAXRoleAttribute kAXRoleDescriptionAttribute kAXSecondFieldAttribute kAXSelectedChildrenAttribute kAXSelectedTextAttribute
         kAXSelectedTextRangeAttribute kAXSelectedTextRangesAttribute kAXSharedCharacterRangeAttribute kAXSharedTextUIElementsAttribute kAXSizeAttribute
         kAXSubroleAttribute kAXTitleAttribute kAXToolbarButtonAttribute kAXTopLevelUIElementAttribute kAXURLAttribute
         kAXValueAttribute kAXValueDescriptionAttribute kAXValueIncrementAttribute kAXVisibleCharacterRangeAttribute kAXVisibleChildrenAttribute
         kAXVisibleColumnsAttribute kAXWindowAttribute kAXYearFieldAttribute kAXZoomButtonAttribute */
        if (attribute == (id)kAXAllowedValuesAttribute) {
            // Handle kAXAllowedValuesAttribute
        } else if (attribute == (id)kAXAMPMFieldAttribute) {
            // Handle kAXAMPMFieldAttribute
        } else if (attribute == (id)kAXCancelButtonAttribute) {
            // Handle kAXCancelButtonAttribute
        } else if (attribute == (id)kAXChildrenAttribute) {
            NSArray* children;
            AXError result = AXUIElementCopyAttributeValue(el, kAXChildrenAttribute, (void*) &children);
            if (result == kAXErrorSuccess) {
                NSMutableArray* pointerArray = [NSMutableArray array];
                for (int i = 0; i < children.count; i++)
                    [pointerArray addObject: [NSValue valueWithPointer: (AXUIElementRef) children[i]]];
                dict[attributeName] = pointerArray;
            } else dict[attributeName] = @[];
        } else if (attribute == (id)kAXCloseButtonAttribute) {
            // Handle kAXCloseButtonAttribute
        } else if (attribute == (id)kAXColumnsAttribute) {
            // Handle kAXColumnsAttribute
        } else if (attribute == (id)kAXColumnHeaderUIElementsAttribute) {
            // Handle kAXColumnHeaderUIElementsAttribute
        } else if (attribute == (id)kAXColumnTitleAttribute) {
            // Handle kAXColumnTitleAttribute
        } else if (attribute == (id)kAXContentsAttribute) {
            // Handle kAXContentsAttribute
        } else if (attribute == (id)kAXDayFieldAttribute) {
            // Handle kAXDayFieldAttribute
        } else if (attribute == (id)kAXDecrementButtonAttribute) {
            // Handle kAXDecrementButtonAttribute
        } else if (attribute == (id)kAXDefaultButtonAttribute) {
            // Handle kAXDefaultButtonAttribute
        } else if (attribute == (id)kAXDescriptionAttribute) {
            // Handle kAXDescriptionAttribute
        } else if (attribute == (id)kAXDisclosedByRowAttribute) {
            // Handle kAXDisclosedByRowAttribute
        } else if (attribute == (id)kAXDisclosedRowsAttribute) {
            // Handle kAXDisclosedRowsAttribute
        } else if (attribute == (id)kAXDisclosingAttribute) {
            // Handle kAXDisclosingAttribute
        } else if (attribute == (id)kAXDocumentAttribute) {
            // Handle kAXDocumentAttribute
        } else if (attribute == (id)kAXEditedAttribute) {
            // Handle kAXEditedAttribute
        } else if (attribute == (id)kAXEnabledAttribute) {
            // Handle kAXEnabledAttribute
        } else if (attribute == (id)kAXExpandedAttribute) {
            // Handle kAXExpandedAttribute
        } else if (attribute == (id)kAXFilenameAttribute) {
            // Handle kAXFilenameAttribute
        } else if (attribute == (id)kAXFocusedApplicationAttribute) {
            AXUIElementRef app;
            AXError result = AXUIElementCopyAttributeValue(el, kAXFocusedApplicationAttribute, (CFTypeRef*) &app);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = [NSValue valueWithPointer: app];
            } else dict[attributeName] = @0;
        } else if (attribute == (id)kAXFocusedAttribute) {
            // Handle kAXFocusedAttribute
        } else if (attribute == (id)kAXFocusedUIElementAttribute) {
            // Handle kAXFocusedUIElementAttribute
        } else if (attribute == (id)kAXFocusedWindowAttribute) {
            // Handle kAXFocusedWindowAttribute
        } else if (attribute == (id)kAXFrontmostAttribute) {
            // Handle kAXFrontmostAttribute
        } else if (attribute == (id)kAXGrowAreaAttribute) {
            // Handle kAXGrowAreaAttribute
        } else if (attribute == (id)kAXHeaderAttribute) {
            // Handle kAXHeaderAttribute
        } else if (attribute == (id)kAXHelpAttribute) {
            // Handle kAXHelpAttribute
        } else if (attribute == (id)kAXHiddenAttribute) {
            // Handle kAXHiddenAttribute
        } else if (attribute == (id)kAXHorizontalScrollBarAttribute) {
            // Handle kAXHorizontalScrollBarAttribute
        } else if (attribute == (id)kAXHourFieldAttribute) {
            // Handle kAXHourFieldAttribute
        } else if (attribute == (id)kAXIncrementorAttribute) {
            // Handle kAXIncrementorAttribute
        } else if (attribute == (id)kAXIndexAttribute) {
            // Handle kAXIndexAttribute
        } else if (attribute == (id)kAXInsertionPointLineNumberAttribute) {
            // Handle kAXInsertionPointLineNumberAttribute
        } else if (attribute == (id)kAXIsApplicationRunningAttribute) {
            NSNumber* isApplicationRunning;
            AXError result = AXUIElementCopyAttributeValue(el, kAXIsApplicationRunningAttribute, (void *)&isApplicationRunning);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = @([isApplicationRunning intValue]);
            } else dict[attributeName] = @(0);
        } else if (attribute == (id)kAXLabelUIElementsAttribute) {
            // Handle kAXLabelUIElementsAttribute
        } else if (attribute == (id)kAXLabelValueAttribute) {
            // Handle kAXLabelValueAttribute
        } else if (attribute == (id)kAXLinkedUIElementsAttribute) {
            // Handle kAXLinkedUIElementsAttribute
        } else if (attribute == (id)kAXMainAttribute) {
            // Handle kAXMainAttribute
        } else if (attribute == (id)kAXMatteContentUIElementAttribute) {
            // Handle kAXMatteContentUIElementAttribute
        } else if (attribute == (id)kAXMatteHoleAttribute) {
            // Handle kAXMatteHoleAttribute
        } else if (attribute == (id)kAXMainWindowAttribute) {
            // Handle kAXMainWindowAttribute
        } else if (attribute == (id)kAXMaxValueAttribute) {
            // Handle kAXMaxValueAttribute
        } else if (attribute == (id)kAXMenuBarAttribute) {
            AXUIElementRef menuBar;
            AXError result = AXUIElementCopyAttributeValue(el, kAXMenuBarAttribute, (CFTypeRef*) &menuBar);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = [NSValue valueWithPointer: menuBar];
            } else dict[attributeName] = @0;
        } else if (attribute == (id)kAXMenuItemCmdCharAttribute) {
            // Handle kAXMenuItemCmdCharAttribute
        } else if (attribute == (id)kAXMenuItemCmdGlyphAttribute) {
            // Handle kAXMenuItemCmdGlyphAttribute
        } else if (attribute == (id)kAXMenuItemCmdModifiersAttribute) {
            // Handle kAXMenuItemCmdModifiersAttribute
        } else if (attribute == (id)kAXMenuItemCmdVirtualKeyAttribute) {
            // Handle kAXMenuItemCmdVirtualKeyAttribute
        } else if (attribute == (id)kAXMenuItemMarkCharAttribute) {
            // Handle kAXMenuItemMarkCharAttribute
        } else if (attribute == (id)kAXMenuItemPrimaryUIElementAttribute) {
            // Handle kAXMenuItemPrimaryUIElementAttribute
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
        } else if (attribute == (id)kAXNextContentsAttribute) {
            // Handle kAXNextContentsAttribute
        } else if (attribute == (id)kAXNumberOfCharactersAttribute) {
            // Handle kAXNumberOfCharactersAttribute
        } else if (attribute == (id)kAXOrientationAttribute) {
            // Handle kAXOrientationAttribute
        } else if (attribute == (id)kAXOverflowButtonAttribute) {
            // Handle kAXOverflowButtonAttribute
        } else if (attribute == (id)kAXParentAttribute) {
            // Handle kAXParentAttribute
        } else if (attribute == (id)kAXPositionAttribute) {
            CFTypeRef positionRef;
            AXError result = AXUIElementCopyAttributeValue(el, kAXPositionAttribute, (void*) &positionRef);
            if (result == kAXErrorSuccess) {
                CGPoint curPt;
                AXValueGetValue(positionRef, kAXValueCGPointType, &curPt);
                dict[attributeName] = @{@"x": @(curPt.x), @"y": @(curPt.y)};
            } else dict[attributeName] = @{@"": @0, @"y": @0};
        } else if (attribute == (id)kAXPreviousContentsAttribute) {
            // Handle kAXPreviousContentsAttribute
        } else if (attribute == (id)kAXProxyAttribute) {
            // Handle kAXProxyAttribute
        } else if (attribute == (id)kAXRoleAttribute) {
            CFTypeRef subroleValue;
            AXError result = AXUIElementCopyAttributeValue(el, kAXRoleAttribute, &subroleValue);
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString *subrole = (__bridge NSString *)subroleValue;
                dict[attributeName] = subrole;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXRoleDescriptionAttribute) {
            // Handle kAXRoleDescriptionAttribute
        } else if (attribute == (id)kAXRowsAttribute) {
            // Handle kAXRowsAttribute
        } else if (attribute == (id)kAXSecondFieldAttribute) {
            // Handle kAXSecondFieldAttribute
        } else if (attribute == (id)kAXSelectedAttribute) {
            // Handle kAXSelectedAttribute
        } else if (attribute == (id)kAXSelectedChildrenAttribute) {
            // Handle kAXSelectedChildrenAttribute
        } else if (attribute == (id)kAXSelectedColumnsAttribute) {
            // Handle kAXSelectedColumnsAttribute
        } else if (attribute == (id)kAXSelectedRowsAttribute) {
            // Handle kAXSelectedRowsAttribute
        } else if (attribute == (id)kAXSelectedTextAttribute) {
            // Handle kAXSelectedTextAttribute
        } else if (attribute == (id)kAXSelectedTextRangeAttribute) {
            // Handle kAXSelectedTextRangeAttribute
        } else if (attribute == (id)kAXSelectedTextRangesAttribute) {
            // Handle kAXSelectedTextRangesAttribute
        } else if (attribute == (id)kAXServesAsTitleForUIElementsAttribute) {
            // Handle kAXServesAsTitleForUIElementsAttribute
        } else if (attribute == (id)kAXSharedCharacterRangeAttribute) {
            // Handle kAXSharedCharacterRangeAttribute
        } else if (attribute == (id)kAXSharedTextUIElementsAttribute) {
            // Handle kAXSharedTextUIElementsAttribute
        } else if (attribute == (id)kAXShownMenuUIElementAttribute) {
            // Handle kAXShownMenuUIElementAttribute
        } else if (attribute == (id)kAXSizeAttribute) {
            CFTypeRef sizeRef;
            AXError result = AXUIElementCopyAttributeValue(el, kAXSizeAttribute, (void*) &sizeRef);
            if (result == kAXErrorSuccess) {
                CGSize curSize;
                AXValueGetValue(sizeRef, kAXValueCGSizeType, &curSize);
                dict[attributeName] = @{@"w": @(curSize.width), @"h": @(curSize.height)};
            } else dict[attributeName] = @{@"w": @0, @"h": @0};
        } else if (attribute == (id)kAXSortDirectionAttribute) {
            // Handle kAXSortDirectionAttribute
        } else if (attribute == (id)kAXSplittersAttribute) {
            // Handle kAXSplittersAttribute
        } else if (attribute == (id)kAXSubroleAttribute) {
            CFTypeRef subroleValue;
            AXError result = AXUIElementCopyAttributeValue(el, kAXSubroleAttribute, &subroleValue);
            if (result == kAXErrorSuccess && CFGetTypeID(subroleValue) == CFStringGetTypeID()) {
                NSString *subrole = (__bridge NSString *)subroleValue;
                dict[attributeName] = subrole;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXTabsAttribute) {
            // Handle kAXTabsAttribute
        } else if (attribute == (id)kAXTitleAttribute) {
            NSString *axTitle = nil;
            AXError result = AXUIElementCopyAttributeValue(el, kAXTitleAttribute, (void *)&axTitle);
            if (result == kAXErrorSuccess) {
                dict[attributeName] = axTitle;
            } else dict[attributeName] = @"";
        } else if (attribute == (id)kAXTitleUIElementAttribute) {
            // Handle kAXTitleUIElementAttribute
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
        } else if (attribute == (id)kAXValueWrapsAttribute) {
            // Handle kAXValueWrapsAttribute
        } else if (attribute == (id)kAXVerticalScrollBarAttribute) {
            // Handle kAXVerticalScrollBarAttribute
        } else if (attribute == (id)kAXVisibleCharacterRangeAttribute) {
            // Handle kAXVisibleCharacterRangeAttribute
        } else if (attribute == (id)kAXVisibleChildrenAttribute) {
            // Handle kAXVisibleChildrenAttribute
        } else if (attribute == (id)kAXVisibleColumnsAttribute) {
            // Handle kAXVisibleColumnsAttribute
        } else if (attribute == (id)kAXVisibleRowsAttribute) {
            // kAXVisibleRowsAttribute
        } else if (attribute == (id)kAXWindowAttribute) {
            // Handle kAXWindowAttribute
        } else if (attribute == (id)kAXWindowsAttribute) {
            // Handle kAXWindowsAttribute
        } else if (attribute == (id)kAXYearFieldAttribute) {
            // Handle kAXYearFieldAttribute
        } else if (attribute == (id)kAXZoomButtonAttribute) {
            // Handle kAXZoomButtonAttribute
        } else {
            if (attribute == (id)kAXPIDAttribute) { //fake kAXAttribute, otherwise no way to get pid with elementDict
                pid_t axPID = -1;
                AXUIElementGetPid(el, &axPID);
                dict[attributeName] = @(axPID);
                continue;
            }
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
//        CFRetain(machPort);
        [eventTapRefs addObject: (__bridge id) machPort];
        [eventTapRefs addObject: [NSValue valueWithPointer: machPort]];
    }
    [eventMap[eventKey] addObject: callback];
}
+ (void) stopListening {
    for (int i = 0; i < eventTapRefs.count / 2; i++) {
        id machPortID = [eventTapRefs objectAtIndex: i*2];
        NSValue* machPortVal = [eventTapRefs objectAtIndex: i*2 + 1];
        CFRelease(machPortVal.pointerValue);
    }
    eventTapRefs = [NSMutableArray array];
    eventMap = [NSMutableDictionary dictionary];
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
+ (NSString*) applescript: (NSString*) scriptTxt {
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *result = @"";
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSAppleScript *script = [[NSAppleScript alloc] initWithSource:scriptTxt];
        NSDictionary<NSString *, id> *error = nil;
        NSAppleEventDescriptor *descriptor = [script executeAndReturnError:&error];
        
        if (descriptor) {
            result = [descriptor stringValue];
        } else {
            NSLog(@"run error: %@", error);
        }
        
        dispatch_semaphore_signal(semaphore);
    });

    // Wait for the script execution to complete
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    return result;
}
+ (void) applescriptAsync: (NSString*) scriptTxt : (void(^)(NSString*)) cb {
    NSTask *task = [[NSTask alloc] init];
    scriptTxt = [NSString stringWithFormat: @"'%@'", [scriptTxt stringByReplacingOccurrencesOfString:@"'" withString:@"\\'"]]; // escape '
    [task setLaunchPath: @"/bin/bash"];
    scriptTxt = [NSString stringWithFormat: @"/usr/bin/osascript -e %@", scriptTxt];
    [task setArguments: [NSArray arrayWithObjects:@"-c", scriptTxt, nil]];
    NSPipe *standardOutput = [[NSPipe alloc] init];
    [task setStandardOutput:standardOutput];
    [[NSNotificationCenter defaultCenter] addObserverForName: NSFileHandleReadCompletionNotification object: [standardOutput fileHandleForReading] queue: nil usingBlock: ^(NSNotification * _Nonnull notification) {
        NSData *data = [[notification userInfo] objectForKey: NSFileHandleNotificationDataItem];
        NSFileHandle *handle = [notification object];
        if ([data length]) {
            NSString* str = [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
            cb([str substringToIndex:[str length]-1]); // remove end of line \n
        } else {
            [[NSNotificationCenter defaultCenter] removeObserver: self name: NSFileHandleReadCompletionNotification object: [notification object]];
            cb(nil);
        }
    }];
    [task launch];
    [[standardOutput fileHandleForReading] readInBackgroundAndNotify];
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
