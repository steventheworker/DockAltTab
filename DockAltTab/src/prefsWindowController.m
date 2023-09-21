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
    [self modeBtn: [[self radioContainer] accessibilityChildren][1 /* index of child titled Windows */]];
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
}


- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
