//
//  app.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface app : NSObject
+ (BOOL) contextMenuExists: (CGPoint)carbonPoint : (NSDictionary*)info;
+ (NSString*) getCurrentVersion;
+ (void) initVars;
+ (void) AltTabShow: (NSString*) appBID;
+ (void) AltTabHide;
+ (float) maxDelay;

@end
NS_ASSUME_NONNULL_END
