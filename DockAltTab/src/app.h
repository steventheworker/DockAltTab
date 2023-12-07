//
//  app.h
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "prefsWindowController.h"

NS_ASSUME_NONNULL_BEGIN
@interface App : NSObject {
    @public
    NSStatusItem* statusItem;
    NSWindow* permissionWindow;
    prefsWindowController* prefsController;
    AXUIElementRef systemWideEl;
    NSMenu* iconMenu;
    CGPoint cursorPos;
    BOOL mousemoveLess;
    BOOL isSparkleUpdaterOpen;
}
+ (instancetype) init: (NSWindow*) window : (NSMenu*) menu : (AXUIElementRef) systemWideAccessibilityElement;
- (void) addMenuIcon: (NSMenu*) menu;
- (void) startListening;
- (void) openPrefs;
- (void) renderAndShowPermissionWindow;
- (void) mousemoveLess: (BOOL) yesno;
@end
NS_ASSUME_NONNULL_END
