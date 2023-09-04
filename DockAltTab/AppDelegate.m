//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import "AppDelegate.h"
#import "src/app.h"
#import "src/globals.h"

App* app = nil;

/*
    AppDelate
*/
@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end
@implementation AppDelegate
- (IBAction)openPrefs:(id)sender {[app openPrefs];}
- (IBAction)quit:(id)sender {[NSApp terminate:nil];}
- (IBAction)restartAltTab:(id)sender {}
- (IBAction)killDock:(id)sender {}

/*
    Lifecycle
*/
- (void) awakeFromNib {/* runs before applicationDidFinishLaunching */}
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {app = [App init: _window : menu];}
- (void)dealloc {//    [super dealloc]; //todo: why doesn't this work
//    [timer invalidate];
//    timer = nil;
//    if (_systemWideAccessibilityObject) CFRelease(_systemWideAccessibilityObject);
}
- (void)applicationWillTerminate:(NSNotification *)aNotification {/* Insert code here to tear down your application */}
- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {return NO;}
- (void)setNilValueForKey:(NSString *)key { // nil UI handling
//    if ([key isEqual:@"dockDelay"]) dockDelayInput.floatValue = dockDelay; // reset text field value on empty (nil)
}
@end
