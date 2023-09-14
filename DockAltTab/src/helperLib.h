//
//  helperLib.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface helperLib : NSObject {}
+ (void) activateWindow: (NSWindow*) window;
+ (void) restartApp;
+ (CFMachPortRef) listenMask: (CGEventMask) emask : (CGEventTapCallBack) handler;
+ (void) on: (NSString*) eventKey : (BOOL (^)(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void* refcon)) callback;
+ (void) stopListening;
+ (void) startListening;
+ (NSString*) eventKeyWithEventType: (CGEventType) type;
@end
NS_ASSUME_NONNULL_END
