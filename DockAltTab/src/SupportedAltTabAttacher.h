//
//  SupportedAltTabAttacher.h
//  DockAltTab
//
//  Created by Steven G on 12/5/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface SupportedAltTabAttacher : NSObject
+ (void) init: (void(^)(void)) cb;
+ (NSButton*) linkBtn: (NSString*) title : (NSString*) url : (NSRect) rect;
@end

NS_ASSUME_NONNULL_END
