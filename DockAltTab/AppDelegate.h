//
//  AppDelegate.h
//  DockAltTab
//
//  Created by Steven G on 5/6/22.
//

#import <Cocoa/Cocoa.h>
#import <Sparkle/Sparkle.h>
#import "src/app.h"

@interface AppDelegate : NSObject <NSApplicationDelegate> {
    @public
    App* app;
    IBOutlet NSMenu *iconMenu;
    __weak IBOutlet NSButton *hasScreenRecordingBtnInfoBtn;
}
@property SPUStandardUpdaterController* updaterController;
- (IBAction)killDock:(id)sender;
- (IBAction)quit:(id)sender;
@end
