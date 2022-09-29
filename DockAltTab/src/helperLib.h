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
+ (NSString*) getDockPosition;
+ (pid_t) getPID: (NSString*) tar;
+ (NSDictionary*) appInfo: (NSString*) owner;
+ (NSScreen*) getScreen: (int) screenIndex;
+ (CGPoint) carbonPointFrom: (NSPoint) cocoaPoint;
+ (void) triggerKeycode: (CGKeyCode) key;
+ (NSRunningApplication*) runningAppFromAxTitle: (NSString*) tar;
+ (int) numWindowsMinimized: (NSString *)owner;
+ (NSMutableArray*) getWindowsForOwner: (NSString *)owner;
+ (NSMutableArray*) getWindowsForOwnerPID: (pid_t) PID;
+ (NSMutableArray*) getRealFinderWindows;
+ (NSApplication *) sharedApplication;
+ (AXUIElementRef) elementAtPoint: (CGPoint) carbonPoint;
+ (NSDictionary*) axInfo: (AXUIElementRef) el;
+ (void) listenScreens;
+ (void) listenClicks;
+ (AppDelegate *) getApp;
+ (NSString*) get: (NSString*) url; // http(s) "GET"
+ (void) killDock;
+ (void) dockSetting: (CFStringRef) pref : (BOOL) val;
+ (void) dockSettingFloat: (CFStringRef) pref : (float) val;
+ (NSString*) twoSigFigs: (float) val;
+ (BOOL) dockautohide;
+ (NSString*) runScript: (NSString*) scriptTxt;
@end
NS_ASSUME_NONNULL_END
