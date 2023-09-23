//
//  prefsWindowController.m
//  DockAltTab
//
//  Created by Steven G on 9/18/23.
//

#import "prefsWindowController.h"
#import "globals.h"
#import "helperLib.h"
#import "DockAltTab.h"
#import "../AppDelegate.h"

@interface prefsWindowController ()

@end

@implementation prefsWindowController
- (void) awakeFromNib {
    [helperLib activateWindow: [self window]]; //activate on launch
//    //render
    [self modeBtn: [[self radioContainer] accessibilityChildren][0 /* index of child titled Ubuntu */]];
    for (NSButtonCell* cell in [[self radioContainer] accessibilityChildren]) [cell setFocusRingType: NSFocusRingTypeNone]; // Remove NSFocusRing (focus border/outline)
}
- (NSView*) radioContainer {
    return [helperLib $0: self.window.contentView : @"modeBtns"];
}
- (IBAction)modeBtn:(id)sender {
    NSDictionary* modeDict = @{@"MacOS": @1, @"Ubuntu": @2, @"Windows": @3};
    NSArray* children = [[self radioContainer] accessibilityChildren];
    for (NSButtonCell* cell in children) [cell setState: [cell.title isEqual: [sender title]] ? NSControlStateValueOn : NSControlStateValueOff];
    [DockAltTab setMode: [modeDict[[sender title]] intValue]];
    setTimeout(^{ //ubuntu mode doesn't need mousemove (workaround for powerpoint notes bug where using ANY method to read the mouse coordinates causes the notes section to lose focus)
        [((AppDelegate*) NSApplication.sharedApplication.delegate)->app mousemoveLess: [[sender title] isEqual: @"Ubuntu"] ? YES : NO];
    }, 0); //wait to do it, since awakeFromNib calls .modeBtn immediately (AppDelegate->app is nil)
}
@end
