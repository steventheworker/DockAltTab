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
+ (void) setHideDelay: (int) milliseconds;
+ (void) setGutter: (int) gutter;
+ (void) startPreviewInterval;
+ (void) stopPreviewInterval;
+ (void) timerTick: (NSTimer*) arg;
+ (pid_t) loadDockPID;
+ (pid_t) loadAltTabPID;
+ (BOOL) loadDockAutohide;
+ (int) loadDockPos;
+ (CGRect) loadDockRect;
+ (void) reconnectDock;
+ (NSMutableDictionary*) elDict: (id) el;
+ (void) activateApp: (NSRunningApplication*) app;
+ (NSPoint) previewLocation: (CGPoint) cursorPos : (id) iconEl;
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt;
+ (void) hidePreviewWindow;
+ (BOOL) isPreviewWindowShowing;
+ (BOOL) mousemove:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (CGPoint) pos;
+ (BOOL) mousemoveUbuntu:   (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousemoveWindows:  (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousedown:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon;
+ (BOOL) mousedownUbuntu:   (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (BOOL) mousedownWindows:  (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseup:          (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon;
+ (BOOL) mouseupUbuntu:     (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseupWindows:    (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (id) el : (NSMutableDictionary*) elDict;
+ (void) spaceChanged: (NSNotification*) note;
@end

NS_ASSUME_NONNULL_END
