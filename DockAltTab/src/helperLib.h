//
//  helperLib.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import "AppDelegate.h"

NS_ASSUME_NONNULL_BEGIN
@interface helperLib : NSObject {}
// formatting
+ (NSString*) twoSigFigs: (float) val;
// misc
+ (NSString*) get: (NSString*) url; // http(s) "GET"
+ (NSString*) runScript: (NSString*) scriptTxt;
+ (void) setTimeout: (void(^)(void)) cb : (int) delay;
// point math / screens
+ (CGPoint) carbonPointFrom: (NSPoint) cocoaPoint;
+ (NSScreen*) getScreen: (int) screenIndex;
+ (void) triggerKeycode: (CGKeyCode) key;
// app stuff
+ (AppDelegate *) getApp;
+ (NSApplication *) sharedApplication;
+ (pid_t) getPID: (NSString*) tar;
+ (NSRunningApplication*) runningAppFromAxTitle: (NSString*) tar;
// windows
+ (int) numWindowsMinimized: (NSString *)owner;
+ (NSMutableArray*) getWindowsForOwner: (NSString *)owner;
+ (NSMutableArray*) getWindowsForOwnerPID: (pid_t) PID;
+ (NSMutableArray*) getRealFinderWindows;
// AXUIElement
+ (NSDictionary*) axInfo: (AXUIElementRef) el;
+ (NSDictionary*) appInfo: (NSString*) owner;
+ (AXUIElementRef) elementAtPoint: (CGPoint) carbonPoint;
// dock stuff
+ (void) dockSetting: (CFStringRef) pref : (BOOL) val;
+ (void) dockSettingFloat: (CFStringRef) pref : (float) val;
+ (NSString*) getDockPosition;
+ (BOOL) dockautohide;
+ (void) killDock;
//event listening
+ (void) listenScreens;
+ (void) listenClicks;
@end
NS_ASSUME_NONNULL_END
