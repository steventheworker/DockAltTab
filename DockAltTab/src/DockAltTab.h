//
//  DockAltTab.h
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "globals.h"
#import "helperLib.h"
#import "prefs.h"
#import "SupportedAltTabAttacher.h"
#import "DockAltTab/MacOSMode.h"
#import "DockAltTab/UbuntuMode.h"
#import "DockAltTab/WindowsMode.h"

//const float PREVIEW_INTERVAL_TICK_DELAY =  0.333; // 0.16666665; // 0.33333 / 2   seconds
extern const int ACTIVATION_MILLISECONDS;
extern pid_t dockPID;
extern pid_t AltTabPID;
//int dockPos = DockBottom;
extern BOOL dockAutohide;
//CGRect dockRect;
//id dockContextMenuClickee; //the dock separator element that was right clicked
//int previewDelay = 0;int previewHideDelay = 0;
extern int thumbnailPreviewDelay;extern BOOL thumbnailPreviewsEnabled;extern int thumbnailPreviewTimeoutRef;extern id _Nullable previewTarget;
extern BOOL keepDockShowing;
extern NSMutableDictionary<NSString*, NSAppleScript*>* _Nonnull scripts;
//float previewGutter = 0;
extern NSMutableDictionary* _Nullable mousedownDict;
extern NSMutableDictionary* _Nullable mousemoveDict;
//NSTimer* previewIntervalTimer;
//CGPoint cursorPos;
//CGRect lastPreviewWinBounds;
extern int activationT;
extern NSMutableDictionary<NSNumber*, NSDictionary<NSString*, NSNumber*>*>* _Nonnull appWindowCounts;
extern BOOL isDockActive;
extern int onScreenFinderWindows(void);


extern Boolean CoreDockGetAutoHideEnabled(void);
extern void CoreDockSetAutoHideEnabled(Boolean flag);

NS_ASSUME_NONNULL_BEGIN

@interface DockAltTab : NSObject
+ (void) init;
+ (void) setMode: (int) mode;
+ (void) setDelay: (float) milliseconds;
+ (void) setHideDelay: (float) milliseconds;
+ (void) setThumbnailPreviewDelay: (float) milliseconds;
+ (void) setThumbnailPreviewsEnabled: (BOOL) tf;
+ (void) setGutter: (float) gutter;
+ (void) setkeepDockShowing: (BOOL) tf;
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
+ (void) unhideApp: (NSRunningApplication*) app;
+ (NSPoint) previewLocation: (CGPoint) cursorPos : (id) iconEl;
+ (NSString*) getShowString: (NSString*) appBID : (CGPoint) pt;
+ (void) hidePreviewWindow;
+ (void) showPreview: (NSString*) tarBID;
+ (BOOL) isPreviewWindowShowing;
+ (BOOL) mousemove:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (CGPoint) pos;
+ (BOOL) mousedown:         (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon;
+ (BOOL) mouseup:          (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon;
+ (void) spaceChanged: (NSNotification*) note;
@end

NS_ASSUME_NONNULL_END
