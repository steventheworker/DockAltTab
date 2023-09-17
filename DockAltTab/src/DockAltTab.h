//
//  DockAltTab.h
//  DockAltTab
//
//  Created by Steven G on 9/17/23.
//

#import <Foundation/Foundation.h>
#import <Carbon/Carbon.h>

NS_ASSUME_NONNULL_BEGIN

@interface DockAltTab : NSObject
+ (void) init;
+ (void) loadDockPid;
+ (NSMutableDictionary*) elDict: (AXUIElementRef) el;
+ (BOOL) mousedown: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
+ (BOOL) mouseup: (CGEventTapProxy) proxy : (CGEventType) type : (CGEventRef) event : (void*) refcon : (AXUIElementRef) el : (NSMutableDictionary*) elDict;
@end

NS_ASSUME_NONNULL_END
