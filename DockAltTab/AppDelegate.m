//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import "AppDelegate.h"
#import "src/globals.h"
#import "src/helperLib.h"
#import "src/app.h"

App* app = nil;

/*
    AppDelate
*/
@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end
@implementation AppDelegate
/* menu icon "window" actions */
- (IBAction)openPrefs:(id)sender {[app openPrefs];}
- (IBAction)quit:(id)sender {[NSApp terminate:nil];}
- (IBAction)restartAltTab:(id)sender {}
- (IBAction)killDock:(id)sender {}

/* permissions window actions */
- (IBAction)restartApp:(id)sender {[helperLib restartApp];}
- (IBAction)hasAccessibilityBtn:(id)sender {[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"]];}
- (IBAction)hasInputMonitoringBtn:(id)sender {[[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"]];}
- (IBAction)hasScreenRecordingBtn:(id)sender {
    CGRequestScreenCaptureAccess(); // prompt user / add entry to Screen Recording app list
    [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString:@"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"]];
}
- (IBAction)hasScreenRecordingBtnTooltip:(id)sender {
    NSHelpManager *helpManager = [NSHelpManager sharedHelpManager];
    [helpManager setContextHelp:[[NSAttributedString alloc] initWithString:[hasScreenRecordingBtnInfoBtn toolTip]] forObject:hasScreenRecordingBtnInfoBtn];
    [helpManager showContextHelpForObject:hasScreenRecordingBtnInfoBtn locationHint:[NSEvent mouseLocation]];
    [helpManager removeContextHelpForObject:hasScreenRecordingBtnInfoBtn];
}


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
