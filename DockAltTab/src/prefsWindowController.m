//
//  prefsWindowController.m
//  DockAltTab
//
//  Created by Steven G on 9/18/23.
//

#import "prefsWindowController.h"
#import "globals.h"
#import "helperLib.h"
#import "prefs.h"
#import "DockAltTab.h"
#import "../AppDelegate.h"

NSDictionary* modeDict = @{@"MacOS": @1, @"Ubuntu": @2, @"Windows": @3};
void dockSettingFloat(CFStringRef pref, float val) { //accepts int or Boolean (as int) settings only
    CFPreferencesSetAppValue(pref, (__bridge CFPropertyListRef _Nullable)([NSNumber numberWithFloat:val]), CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
}
void dockSettingBOOL(CFStringRef pref, BOOL val) { //accepts int or Boolean (as int) settings only
    CFPreferencesSetAppValue(pref, !val ? kCFBooleanFalse : kCFBooleanTrue, CFSTR("com.apple.dock"));
    CFPreferencesAppSynchronize(CFSTR("com.apple.dock"));
}
BOOL getDockBOOLPref(NSString* key) {
    Boolean valid = false;
    return CFPreferencesGetAppBooleanValue((__bridge CFStringRef) key, CFSTR("com.apple.dock"), &valid);
}
float getDockFloatPref(NSString* key) {
    NSString* val = CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef) key, CFSTR("com.apple.dock")));
    if (!val && [key isEqual: @"autohide-delay"]) return 0.5; //default 0.5
    return [val floatValue];
}

@interface prefsWindowController ()
@end
@implementation prefsWindowController
- (void) awakeFromNib {
    //set default prefs  &&  log current values
    NSLog(@"prefs: %@", [prefs setDefaults: @{
        @"showMenubarIcon": @YES,
        @"previewMode": @1, //hoverPreviews
        @"spaceSwitchingDisabled": @YES,
        @"previewDelay": @0,
        @"updatePolicy": @"autocheck" /* manual / autocheck / autoinstall */
    }]);
//    [helperLib activateWindow: [self window]]; //activate on launch
    [self setUpdatePolicy];
    if ([prefs getIntPref: @"previewMode"] == 2) setTimeout(^{[((AppDelegate*) NSApplication.sharedApplication.delegate)->app mousemoveLess: YES];}, 0); //wait for del->app to be defined before clickMode==mousemoveless

//    //render
    [self modeBtn: [[self radioContainer] accessibilityChildren][2 /* index of child titled MacOS */]];
    for (NSButtonCell* cell in [[self radioContainer] accessibilityChildren]) [cell setFocusRingType: NSFocusRingTypeNone]; // Remove NSFocusRing (focus border/outline)
}
- (void) setUpdatePolicy {
    NSString* updatePolicy = [prefs getStringPref: @"updatePolicy"];
    SPUStandardUpdaterController* sucontroller = ((AppDelegate*) NSApplication.sharedApplication.delegate).updaterController;
    if (![updatePolicy isEqual: @"manual"]) [[sucontroller updater] setAutomaticallyChecksForUpdates: YES];
    if ([updatePolicy isEqual: @"autoinstall"]) [[sucontroller updater] setAutomaticallyDownloadsUpdates: YES];
}
- (void) render {
    //version
    ((NSTextField*) [helperLib $0: self.window.contentView : @"appVersionStr"]).cell.title = [@"v" stringByAppendingString: [helperLib appVersion]];
    
    //add menu icon checkbox
    ((NSButton*) [helperLib $0: self.window.contentView : @"menuIconCheckbox"]).cell.state = [prefs getBoolPref: @"showMenubarIcon"];
    
    //updatePolicy
    NSString* updatePolicy = [prefs getStringPref: @"updatePolicy"];
    if ([updatePolicy isEqual: @"manual"])
        ((NSButton*) [helperLib $0: self.window.contentView : @"updateManualBtn"]).cell.state = YES;
    if ([updatePolicy isEqual: @"autocheck"])
        ((NSButton*) [helperLib $0: self.window.contentView : @"updateAutoBtn"]).cell.state = YES;
    if ([updatePolicy isEqual: @"autoinstall"])
        ((NSButton*) [helperLib $0: self.window.contentView : @"updateAutoInstallBtn"]).cell.state = YES;

    //select mode radio btn
    int previewMode = [prefs getIntPref: @"previewMode"];
    ((NSButton*) [helperLib $0: self.window.contentView : (previewMode == 1) ? @"hoverModeBtn" : @"clickModeBtn"]).cell.state = YES;

    //delay slider & label
    ((NSSlider*) [helperLib $0: self.window.contentView : @"delaySlider"]).floatValue = [prefs getFloatPref: @"previewDelay"];
    NSString* twoSigFigs = [NSString stringWithFormat: @"%.02f", [prefs getFloatPref: @"previewDelay"] / 100 * 2];
    ((NSTextField*) [helperLib $0: self.window.contentView : @"delayLabel"]).cell.title = twoSigFigs;
    
    //check/uncheck spaceSwitching
//    ((NSButton*) [helperLib $0: self.window.contentView : @"spaceSwitchingDisabledBtn"]).cell.state = [prefs getBoolPref: @"spaceSwitchingDisabled"];
    
    /* Dock Settings */
    // differentiate hidden apps - CFSTR("showhidden")
    ((NSButton*) [helperLib $0: self.window.contentView : @"differentiateHiddenAppsBtn"]).cell.state = getDockBOOLPref(@"showhidden");
    // dock delay - CFSTR("autohide-delay")
    ((NSSlider*) [helperLib $0: self.window.contentView : @"dockDelayInput"]).floatValue = getDockFloatPref(@"autohide-delay");
    // lock dock pos - CFSTR("position-immutable")
    ((NSButton*) [helperLib $0: self.window.contentView : @"lockDockPosBtn"]).cell.state = getDockBOOLPref(@"position-immutable");
    // lock dock size - CFSTR("size-immutable")
    ((NSButton*) [helperLib $0: self.window.contentView : @"lockDockSizeBtn"]).cell.state = getDockBOOLPref(@"size-immutable");
    // lock dock contents - CFSTR("contents-immutable")
    ((NSButton*) [helperLib $0: self.window.contentView : @"lockDockContentsBtn"]).cell.state = getDockBOOLPref(@"contents-immutable");
}
/* bindings */
- (IBAction)quit:(id)sender {setTimeout(^{[((AppDelegate*) NSApplication.sharedApplication.delegate) quit: nil];}, 200);}
- (IBAction)checkForUpdates:(id)sender {
    AppDelegate* del = ((AppDelegate*) NSApplication.sharedApplication.delegate);
    NSMenu* iconMenu = del->iconMenu;
    del->app->isSparkleUpdaterOpen = YES;
    for (NSMenuItem* i in iconMenu.accessibilityChildren)
        if ([i.identifier isEqual: @"checkForUpdatesMenuItem"]) [i accessibilityPerformPress];
}
- (IBAction)killDock:(id)sender {
    [helperLib killDock];
    [DockAltTab reconnectDock];
}
- (IBAction)checkUncheckMenuIcon:(id)sender {
    App* app = ((AppDelegate*) NSApplication.sharedApplication.delegate)->app;
    [app->statusItem setVisible: (BOOL) [sender state]];
    [prefs setBoolPref: @"showMenubarIcon" : (BOOL) [sender state]];
}
- (IBAction)updateChoice:(id)sender {
    if ([((NSButton*)sender).identifier isEqual: @"updateManualBtn"])
        [prefs setStringPref: @"updatePolicy" : @"manual"];
    if ([((NSButton*)sender).identifier isEqual: @"updateAutoBtn"])
        [prefs setStringPref: @"updatePolicy" : @"autocheck"];
    if ([((NSButton*)sender).identifier isEqual: @"updateAutoInstallBtn"])
        [prefs setStringPref: @"updatePolicy" : @"autoinstall"];
    [self setUpdatePolicy];
}
- (NSView*) radioContainer {
    return [helperLib $0: self.window.contentView : @"modeBtns"];
}
- (IBAction)modeBtn:(id)sender {
    NSArray* children = [[self radioContainer] accessibilityChildren];
    for (NSButtonCell* cell in children) [cell setState: [cell.title isEqual: [sender title]] ? NSControlStateValueOn : NSControlStateValueOff];
    [DockAltTab setMode: [modeDict[[sender title]] intValue]];
    //    [prefs setIntPref: @"previewMode" : mode];
    setTimeout(^{ //ubuntu mode doesn't need mousemove (workaround for powerpoint notes bug where using ANY method to read the mouse coordinates causes the notes section to lose focus)
        [((AppDelegate*) NSApplication.sharedApplication.delegate)->app mousemoveLess: [[sender title] isEqual: @"Ubuntu"] ? YES : NO];
    }, 0); //wait to do it, since awakeFromNib calls .modeBtn immediately (AppDelegate->app is nil)
}
//- (IBAction)spaceSwitchingChoice:(id)sender {
//    [prefs setBoolPref: @"spaceSwitchingDisabled" : [sender state]];
//    [DockExpose spaceSwitchingDisabled: [sender state]];
//}
- (IBAction)delayChanged:(id)sender {
    float val = ((NSSlider*) sender).floatValue / 100 * 2;
    NSString* twoSigFigs = [NSString stringWithFormat: @"%.02f", val];
    ((NSTextField*) [helperLib $0: self.window.contentView : @"delayLabel"]).cell.title = twoSigFigs;
    [prefs setFloatPref: @"previewDelay" : ((NSSlider*) sender).floatValue];
    [DockAltTab setDelay: ((NSSlider*) sender).floatValue * 10 * 2 /* milliseconds */];
}
/* dock pref bindings */
- (IBAction)lockDockPosition:(id)sender {dockSettingBOOL(CFSTR("position-immutable"), ((NSButton*) sender).state);}
- (IBAction)lockDockSize:(id)sender {dockSettingBOOL(CFSTR("size-immutable"), ((NSButton*) sender).state);}
- (IBAction)lockDockContents:(id)sender {dockSettingBOOL(CFSTR("contents-immutable"), ((NSButton*) sender).state);}
- (IBAction)toggleDifferentiateHidden:(id)sender {dockSettingBOOL(CFSTR("showhidden"), ((NSButton*) sender).state);}
- (IBAction)setDockDelay:(id)sender { //onSubmit / enter key / "Continuously Updates Value" checked in bindings
//    float setVal = ((NSSlider*) sender).floatValue;
//    if (setVal < 0) setVal = fabs(setVal);
    dockSettingFloat(CFSTR("autohide-delay"), ((NSSlider*) sender).floatValue);
//    ((NSSlider*) sender).floatValue = setVal;
}
- (void)setNilValueForKey: (NSString*) key {
    NSLog(@"nil: %@", key);
//    if ([key isEqual:@"dockDelay"]) dockDelayInput.floatValue = dockDelay; // reset text field value on empty (nil)
}
@end
