//
//  DockAltTab.h
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface DockAltTab : NSObject
+ (void) init;
+ (void) setMode: (int) mode;
+ (pid_t) loadDockPID;
+ (BOOL) loadDockAutohide;
+ (NSString*) loadDockPos;
+ (CGRect) loadDockRect;
+ (NSMutableDictionary*) elDict: (AXUIElementRef) el;
+ (void) activateApp: (NSRunningApplication*) app;
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt;
+ (void) hidePreviewWindow;
+ (BOOL) isPreviewWindowShowing;
+ (BOOL) mousedown:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
+ (BOOL) mousedownUbuntu:   (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
+ (BOOL) mousedownWindows:  (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
+ (BOOL) mouseup:          (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
+ (BOOL) mouseupUbuntu:     (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
+ (BOOL) mouseupWindows:    (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) cursorPos;
@end

NS_ASSUME_NONNULL_END
