//
//  helperLib.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

#define kAXPIDAttribute                CFSTR("AXPID") //dunno why AXUIElementGetPid is so special (no way to get pid with AXUIElementCopyAttributeValue)

NS_ASSUME_NONNULL_BEGIN
@interface helperLib : NSObject {}
/* AXUIElement */
+ (void) setSystemWideEl: (AXUIElementRef) el;
+ (AXUIElementRef) elementAtPoint: (CGPoint) pt;
+ (NSDictionary*) elementDict: (AXUIElementRef) el : (NSDictionary*) attributeDict;
/* events*/
+ (CFMachPortRef) listenMask: (CGEventMask) emask : (CGEventTapCallBack) handler;
+ (void) on: (NSString*) eventKey : (BOOL (^)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)) callback;
+ (void) stopListening;
+ (NSString*) eventKeyWithEventType: (CGEventType) type;
/* misc. */
+ (void) activateWindow: (NSWindow*) window;
+ (void) restartApp;
@end
NS_ASSUME_NONNULL_END
