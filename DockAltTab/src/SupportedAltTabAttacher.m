//
//  SupportedAltTabAttacher.m
//  DockAltTab
//
//  Created by Steven G on 12/5/23.
//

#import "SupportedAltTabAttacher.h"
#import "globals.h"
#import "helperLib.h"

void (^attachCallback)(void);
NSWindow* unsupportedWindow;

NSWindow* createWindow(NSScreen* screen) {
    screen = screen ? screen : [helperLib primaryScreen];
    float w = 300;
    float h = 80;
    NSWindow* spaceWindow = [[NSWindow alloc] initWithContentRect: NSMakeRect(screen.frame.size.width/2 - w/2, screen.frame.size.height/2 - h/2, w, h)
                                                        styleMask: (/*NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable */NSWindowStyleMaskBorderless)
                                                          backing: NSBackingStoreBuffered
                                                            defer: NO
                                                           screen: screen];
//    [spaceWindow setIdentifier: @"spacewindow"];
    [spaceWindow setLevel: kCGMainMenuWindowLevel];
//    [spaceWindow setTitle: [NSString stringWithFormat: @"%d", spaceIndex]];
//    [spaceWindow setIgnoresMouseEvents: YES]; //pass clicks through (which it already does so, when using nscolor.clearcolor (For some reason))
    [spaceWindow setBackgroundColor: [NSColor colorWithSRGBRed: 0.7 green: 0.2 blue: 0.2 alpha: 0.75]];
    [spaceWindow makeKeyAndOrderFront: nil]; //pop it up
//    [spaceWindow setFrame: NSMakeRect(screen.frame.origin.x, screen.frame.origin.y, 0, 0) display: YES]; //place on bottom left corner of screen
//    CFBridgingRetain(spaceWindow);
    return spaceWindow;
}
NSButton* linkBtn(NSString* title, NSString* url, NSRect rect) {return [SupportedAltTabAttacher linkBtn: title : url : rect];}
void renderUnsupportedWindow(void) {
    NSView* container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 80)];
    NSTextView* txt = [[NSTextView alloc] initWithFrame: NSMakeRect(0, 50, 300, 30)];
    [txt setBackgroundColor: NSColor.clearColor];
    [txt setString: @"The Official AltTab is currently unspported."];
    [container addSubview: txt];
    [container addSubview: linkBtn(@"More Info", @"https://github.com/lwouis/alt-tab-macos/pull/1590#issuecomment-1131809994", NSMakeRect(80, 30, 99, 30))];
    [container addSubview: linkBtn(@"Download supported AltTab", @"https://github.com/steventheworker/alt-tab-macos/releases/download/1.91.0/DockAltTab.AltTab.v6.61.0.zip", NSMakeRect(20, 0, 240, 30))];
    [unsupportedWindow.contentView addSubview: container];
}

@implementation SupportedAltTabAttacher
+ (void) init: (void (^)(void)) cb {
    if (unsupportedWindow) return;
    unsupportedWindow = createWindow(nil);
    renderUnsupportedWindow();
    attachCallback = cb;
    [self perpetuate];
}
+ (NSButton*) linkBtn: (NSString*) title : (NSString*) url : (NSRect) rect {
    NSButton* btn = [[NSButton alloc] initWithFrame: rect];
    //make link clickable
    [btn setTitle: title];
    [btn setTarget: self];
    [btn setAction: @selector(openURL:)];
    [btn setIdentifier: url]; // Using hash of URL as a tag to uniquely identify the button
    return btn;
}
+ (void) perpetuate {
    setTimeout(^{
        if ([helperLib appWithBID: @"com.steventheworker.alt-tab-macos"].processIdentifier) {
            [unsupportedWindow close];
            attachCallback();
            return;
        }
        [self perpetuate];
    }, 1000);
}
+ (void) openURL: (id)sender {
    NSButton* button = (NSButton*)sender;
    [NSWorkspace.sharedWorkspace openURL: [NSURL URLWithString: button.identifier]];
}
@end
