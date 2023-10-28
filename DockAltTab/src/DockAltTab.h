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
+ (void) setDelay: (int) milliseconds;
+ (void) startPreviewInterval;
+ (void) stopPreviewInterval;
+ (void) timerTick: (NSTimer*) arg;
+ (pid_t) loadDockPID;
+ (pid_t) loadAltTabPID;
+ (BOOL) loadDockAutohide;
+ (NSString*) loadDockPos;
+ (CGRect) loadDockRect;
+ (void) reconnectDock;
+ (NSMutableDictionary*) elDict: (AXUIElementRef) el;
+ (void) activateApp: (NSRunningApplication*) app;
+ (NSPoint) previewLocation: (CGPoint) cursorPos : (AXUIElementRef) iconEl;
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt;
+ (void) hidePreviewWindow;
+ (BOOL) isPreviewWindowShowing;
+ (BOOL) mousemove:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict : (CGPoint) pos;
+ (BOOL) mousemoveUbuntu:   (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousemoveWindows:  (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousedown:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousedownUbuntu:   (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousedownWindows:  (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseup:          (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseupUbuntu:     (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseupWindows:    (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (void) spaceChanged: (NSNotification*) note;
@end

NS_ASSUME_NONNULL_END
