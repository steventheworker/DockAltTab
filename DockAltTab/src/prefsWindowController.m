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

void radioClicked(id sender, NSString* selfLabelValue) {
    NSArray* children = [[sender superview] accessibilityChildren];
    for (NSButtonCell* cell in children) {
        if (![cell.title isEqual: selfLabelValue])
            [cell setState: NSControlStateValueOff];
    }
    
    //events stop working after [DockAltTab setMode:] is called...
    [helperLib stopListening];
    AppDelegate* del = (AppDelegate *) [[NSApplication sharedApplication] delegate];
    [del->app startListening];
}

@implementation prefsWindowController
- (void) awakeFromNib {
//    [self showWindow: [self window]]; //activate on launch
    //render
    NSArray* radioBtnContainerChildren = [[[self.window contentView] subviews][1] accessibilityChildren];
    for (NSButtonCell* cell in radioBtnContainerChildren) {
        [cell setFocusRingType: NSFocusRingTypeNone]; // Remove NSFocusRing (focus border/outline)
    }
}
- (IBAction)macOSModeBtn:(id)sender {
    radioClicked(sender, @"MacOS");
    [DockAltTab setMode: 1];
}
- (IBAction)ubuntuModeBtn:(id)sender {
    radioClicked(sender, @"Ubuntu");
    [DockAltTab setMode: 2];
}
- (IBAction)windowsModeBtn:(id)sender {
    radioClicked(sender, @"Windows");
    [DockAltTab setMode: 3];
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
