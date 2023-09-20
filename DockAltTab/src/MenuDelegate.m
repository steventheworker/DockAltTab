//
//  MenuDelegate.m
//  DockAltTab
//
//  Created by Steven G on 9/16/23.
//

#import "globals.h"
#import "MenuDelegate.h"
#import "helperLib.h"
#import "../AppDelegate.h"

//clicking menu bar icon with kCGEventTapOptionDefault (modifying events) stops working if you click the menubar icon
//this releases the old listeners, and adds new ones when the menu closes
@implementation MenuDelegate
- (void)menuWillOpen:(NSMenu *)menu {
//    [helperLib stopListening];
}
- (void)menuDidClose:(NSMenu *)menu {
//    AppDelegate* del = (AppDelegate *) [[NSApplication sharedApplication] delegate];
//    [del->app startListening];
}
@end
