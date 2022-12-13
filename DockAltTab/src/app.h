//
//  app.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface app : NSObject
+ (BOOL) contextMenuExists: (CGPoint)carbonPoint : (NSDictionary*)info;
+ (void) getCurrentVersion;
+ (void) init;
+ (NSString*) getShowString: (NSString*) appBID;
+ (void) AltTabShow: (NSString*) appBID;
+ (void) AltTabHide;
+ (float) maxDelay;
+ (NSString*) reopenDockStr: (BOOL) triggerEscape;
+ (void) activateApp: (NSRunningApplication*) app;
+ (void) sendClick : (CGPoint) pt;
+ (void) viewToFront: (NSView*) v; // send to top layer
+ (void) viewToBack: (NSView*) v; // send to bottom layer
+ (int) ATWindowCount: (pid_t) AltTabPID;
@end
NS_ASSUME_NONNULL_END
