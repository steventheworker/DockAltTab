//
//  app.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN
@interface App : NSObject {
    NSStatusItem* statusItem;
    NSWindow* permissionWindow;
    NSWindowController* prefsController;
}
+ (instancetype) init: (NSWindow*) window : (NSMenu*) menu;
- (void) openPrefs;
- (void) addMenuIcon: (NSMenu*) menu;
- (void) renderAndShowPermissionWindow;
@end
NS_ASSUME_NONNULL_END
