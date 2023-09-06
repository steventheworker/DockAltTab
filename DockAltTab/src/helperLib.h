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
@end
NS_ASSUME_NONNULL_END
