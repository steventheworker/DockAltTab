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
    NSWindow* win = [NSWindow.alloc initWithContentRect: NSMakeRect(screen.frame.size.width/2 - w/2, screen.frame.size.height/2 + h/2, w, h)
                                                        styleMask: (/*NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskResizable */NSWindowStyleMaskBorderless)
                                                          backing: NSBackingStoreBuffered
                                                            defer: NO
                                                           screen: screen];
//    [win setIdentifier: @"spacewindow"];
    [win setLevel: kCGMainMenuWindowLevel];
    [win setTitle: @"AltTab Attacher"];
    [win setBackgroundColor: [NSColor colorWithSRGBRed: 0.25 green: 0.25 blue: 0.25 alpha: 0.95]];
    [win makeKeyAndOrderFront: nil]; //pop it up
//    [win setFrame: NSMakeRect(screen.frame.origin.x, screen.frame.origin.y, 0, 0) display: YES]; //place on bottom left corner of screen
    CFBridgingRetain(win);
    return win;
}
NSButton* quitBtn(NSRect rect) {return [SupportedAltTabAttacher quitBtn: rect];}
NSButton* linkBtn(NSString* title, NSString* url, NSRect rect) {return [SupportedAltTabAttacher linkBtn: title : url : rect];}
NSButton* applescriptBtn(NSString* title, NSRect rect) {return [SupportedAltTabAttacher applescriptBtn: title : rect];}
void renderUnsupportedWindow(void) {
    NSView* container = [NSView.alloc initWithFrame: NSMakeRect(0, 0, 300, 80)];
    [container addSubview: quitBtn(NSMakeRect(182, 59, 125, 20))];
    NSTextView* txt = [NSTextView.alloc initWithFrame: NSMakeRect(2, 63, 175, 14)];
    [txt setString: [helperLib appWithBID: @"com.lwouis.alt-tab-macos"] ? @"Incompatible AltTab Detected." : @"AltTab is not running."];
    [container addSubview: txt];
    [container addSubview: linkBtn(@"Download scriptable AltTab", @"https://github.com/steventheworker/alt-tab-macos/releases/download/1.94.0/AltTab-scriptable-1.94.0.zip", NSMakeRect(-7, 35, 190, 20))];
    [container addSubview: applescriptBtn(@"tell application id \"com.steventheworker.alt-tab-macos\" to activate", NSMakeRect(0, 0, 300, 30))];
    [unsupportedWindow.contentView addSubview: container];
}

@implementation SupportedAltTabAttacher
+ (void) init: (void (^)(void)) cb {
    unsupportedWindow = createWindow(nil);
    renderUnsupportedWindow();
    attachCallback = cb;
    [self perpetuate];
}
+ (NSButton*) quitBtn: (NSRect) rect {
    NSButton* btn = [[NSButton alloc] initWithFrame: rect];
    [btn setTitle: @"Quit DockAltTab"];
    [btn setAction: @selector(quit:)];
    return btn;
}
+ (NSButton*) linkBtn: (NSString*) title : (NSString*) url : (NSRect) rect {
    NSButton* btn = [[NSButton alloc] initWithFrame: rect];
    [btn setTitle: title];
    [btn setTarget: self];
    [btn setAction: @selector(openURL:)];
    [btn setIdentifier: url]; // Using hash of URL as a tag to uniquely identify the button
    return btn;
}
+ (NSView*) applescriptBtn: (NSString*) title : (NSRect) rect {
    NSView* v = [NSView.alloc initWithFrame: rect];
    
    int btnw = 30, btnh = 30;
    NSButton* btn = [[NSButton alloc] initWithFrame: NSMakeRect(rect.size.width - btnw, rect.size.height - btnh, btnw, btnh)];
    [btn setTitle: @"⏵"];
    [btn setIdentifier: title];
    [btn setTarget: self];
    [btn setAction: @selector(runApplescript:)];
    
    NSTextView* label = [NSTextView.alloc initWithFrame: rect];
    [label setString: title];
    [label setBackgroundColor: [NSColor colorWithRed:0 green:0 blue:0 alpha:0]];
    [label setFont: [NSFont monospacedSystemFontOfSize: 10 weight: 0]];

    [v addSubview: label];
    [v addSubview: btn];
    return v;
}
+ (void) perpetuate {
    setTimeout(^{
        if ([helperLib appWithBID: @"com.steventheworker.alt-tab-macos"]) {
            [unsupportedWindow close];
            attachCallback();
            unsupportedWindow = nil;
            return;
        }
        [self perpetuate];
    }, 1000);
}
+ (void) quit: (id)sender {[NSApp terminate: nil];}
+ (void) runApplescript: (id)sender {[helperLib applescriptAsync: ((NSButton*)sender).identifier : ^(NSString* response) {}];}
+ (void) openURL: (id)sender {
    NSButton* button = (NSButton*)sender;
    [NSWorkspace.sharedWorkspace openURL: [NSURL URLWithString: button.identifier]];
}
@end
