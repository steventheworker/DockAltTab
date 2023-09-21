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
    @public
    NSStatusItem* statusItem;
    NSWindow* permissionWindow;
    NSWindowController* prefsController;
    AXUIElementRef systemWideEl;
    NSMenu* iconMenu;
    CGPoint cursorPos;
}
+ (instancetype) init: (NSWindow*) window : (NSMenu*) menu : (AXUIElementRef) systemWideAccessibilityElement;
- (void) addMenuIcon: (NSMenu*) menu;
- (void) startListening;
- (void) openPrefs;
- (void) renderAndShowPermissionWindow;
@end
NS_ASSUME_NONNULL_END
