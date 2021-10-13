//
//  AppDelegate.m
//  DockAltTab
//
//  Created by Steven Gonzales on 9/6/21.
//
#import "AppDelegate.h"

NSString* versionLink = @"https://dockalttab.netlify.app/currentversion.txt";
const float DOCKPOS_DELAY = 5; //update overlayPID, dockPos every x minutes
const float TICK_DELAY = 0.8; //call main fn every x seconds
const float MINIMAL_DELAY = 0.07; //minimum seconds before UI refresh is guaranteed
const int CONTEXTDISTANCE = 150; //dock testPoint/contextmenu's approx. distance from pointer
//lib
int numWindowsMinimized(NSString* tar) {
    int numWindows = 0; //# minimized windows on active space
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionAll|kCGWindowListExcludeDesktopElements, kCGNullWindowID);
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        //get dictionary data
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![tar isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]] || [[win objectForKey:@"kCGWindowLayer"] intValue] != 0) continue;
        // Get the AXUIElement windowList (e.g. elementList)
        int winPID = [[win objectForKey:@"kCGWindowOwnerPID"] intValue];
        AXUIElementRef appRef = AXUIElementCreateApplication(winPID);
        CFArrayRef elementList;
        AXUIElementCopyAttributeValue(appRef, kAXWindowsAttribute, (CFTypeRef *)&elementList);
        bool onActiveSpace = YES;
        //loop through looking for minimized && onActiveSpace
        long int numElements = elementList ? CFArrayGetCount(elementList) : 0;
        for (int j = 0; j < numElements; j++) {
            AXUIElementRef winElement = CFArrayGetValueAtIndex(elementList, j);
            CFBooleanRef winMinimized;
            AXUIElementCopyAttributeValue(winElement, kAXMinimizedAttribute, (CFTypeRef *)&winMinimized);
            if (winMinimized == kCFBooleanTrue && onActiveSpace) numWindows++;
            CFRelease(winMinimized);
        }
    }
//    CFRelease(elementList); //apparently i may be overreleasing, causing crashes?
    CFRelease(windowList);
//    NSLog(@"found %d minimized windows", numWindows);
    return numWindows;
}
NSString * getDataFrom(NSString *url) {
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
    [request setHTTPMethod:@"GET"];
    [request setURL:[NSURL URLWithString:url]];
    NSError *error = nil;
    NSHTTPURLResponse *responseCode = nil;
    NSData *oResponseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&responseCode error:&error]; //todo: fix warning
    if ([responseCode statusCode] != 200) {
        NSLog(@"Error getting %@, HTTP status code %li", url, [responseCode statusCode]);
        return nil;
    }
    return [[NSString alloc] initWithData:oResponseData encoding:NSUTF8StringEncoding];
}
NSString* getCurrentVersion(void) {
    return getDataFrom(versionLink);
}
NSScreen* screenWithPoint(NSPoint p) {
    for (NSScreen *candidate in [NSScreen screens])
        if (NSPointInRect(p, [candidate frame]))
            return candidate;
    return nil;
}
CGPoint carbonPointFrom(NSPoint cocoaPoint) {
    NSScreen* screen = screenWithPoint(NSZeroPoint);
    float menuScreenHeight = NSMaxY([screen frame]);
    return CGPointMake(cocoaPoint.x,  menuScreenHeight - cocoaPoint.y);
}
void triggerKeycode(CGKeyCode key) {
    CGEventSourceRef src = CGEventSourceCreate(kCGEventSourceStateHIDSystemState);
    CGEventPost(kCGHIDEventTap, CGEventCreateKeyboardEvent(src, key, true));
    CGEventPost(kCGHIDEventTap, CGEventCreateKeyboardEvent(src, key, false));
    CFRelease(src);
}
NSMutableString* getDockPosition(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    return [[defaults persistentDomainForName:@"com.apple.dock"] valueForKey:@"orientation"];
}
pid_t getPID(NSString* tar) { //PID from bundleIdentifier
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.bundleIdentifier]) continue;
        return cur.processIdentifier;
    }
    return 0;
}
NSRunningApplication* runningAppFromAxTitle(NSString* tar) {
    NSArray *appList = [[NSWorkspace sharedWorkspace] runningApplications];
    for (int i = 0; i < appList.count; i++) {
        NSRunningApplication *cur = appList[i];
        if (![tar isEqualTo: cur.localizedName]) continue;
        return cur;
    }
    return nil;
}
NSMutableArray* getWindowIdsForOwner(NSString *owner) {
    if (!owner || [@"" isEqual:owner]) return nil;
    CFArrayRef windowList = CGWindowListCopyWindowInfo(kCGWindowListOptionOnScreenOnly, kCGNullWindowID);
    NSMutableArray *windows = [NSMutableArray new];
    long int windowCount = CFArrayGetCount(windowList);
    for (int i = 0; i < windowCount; i++) {
        NSDictionary *win = CFArrayGetValueAtIndex(windowList, i);
        if (![owner isEqualTo:[win objectForKey:@"kCGWindowOwnerName"]]) continue;
        [windows addObject:[win objectForKey:@"kCGWindowNumber"]];
    }
    return windows;
}
NSDictionary* appInfo(NSString* owner) {
    NSMutableArray* windows = getWindowIdsForOwner(owner); //on screen windows
    //hidden & minimized (off screen windows)
    BOOL isHidden = NO;
    BOOL isMinimized = NO;
    if (runningAppFromAxTitle(owner).isHidden) isHidden = YES;
    if (numWindowsMinimized(owner)) isMinimized = YES;
    //add missing window(s) (a window can be hidden & minimized @ same time (don't want two entries))
    if (isHidden || isMinimized) [windows addObject:@123456789]; //todo: properly add these two windowTypes to windowNumberList, but works
    return @{
        @"windows": windows,
        @"numWindows": @([windows count]),
        @"isHidden": [NSNumber numberWithBool:isHidden],
        @"isMinimized": [NSNumber numberWithBool:isMinimized],
    };
}
void setActiveApp(NSString *tar) {
     NSRunningApplication* app = runningAppFromAxTitle(tar); //only activate apps that aren't yet active (just in case it's slow 🤷‍♀️)
     if (![app isActive]) [app activateWithOptions: NSApplicationActivateIgnoringOtherApps];
}

//Show / Hide "Overlay"
void triggerEscape(AppDelegate* app) {
    if ([app->targetApp isEqual:@"Adobe Premiere Pro 2021"]) return;
    triggerKeycode(app->wasMinimized || app->wasHidden ? 53 : 55); //command ((55) is another way to hideOverlay, but this will never produce a beep sound if there's a mistake (unlike escape), it will also annoyingly force whatever minimized/hidden AltTab window is selected into focus (so we still use escape too))
}
void AltTabShow(NSString *tar, int numWindows, AppDelegate* app) {
    if ([app->targetApp isEqual:tar]) return; //don't hide, don't show & maintain/keep pointing @ tar
    if (![@"" isEqual:app->targetApp] && app->targetApp) {
        triggerEscape(app); //if overlay currently visible (Otherwise AltTab will keep/merge different app windows)
        
        [app->targetApp setString:@""];
        //settimeout & try again once Escaped old AltTab overlay
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * MINIMAL_DELAY), dispatch_get_main_queue(), ^(void){
            AltTabShow(tar, numWindows, app);
        });
        return;
    }
    app->targetApp = [tar mutableCopy];
    setActiveApp(tar);
    //trigger command + tilde   BUT KEEP holding down command (--ACTUALLY I didn't have to do anything for this it just works out that way! somehow o.o)
    CGEventSourceRef src =
      CGEventSourceCreate(kCGEventSourceStateHIDSystemState);

    CGEventRef cmdd = CGEventCreateKeyboardEvent(src, 0x38, true);
    CGEventRef cmdu = CGEventCreateKeyboardEvent(src, 0x38, false);
    CGEventRef tilded = CGEventCreateKeyboardEvent(src, (CGKeyCode)50, true);
    CGEventRef tildeu = CGEventCreateKeyboardEvent(src, (CGKeyCode)50, false);

    CGEventSetFlags(tilded, kCGEventFlagMaskCommand);
    CGEventSetFlags(tildeu, kCGEventFlagMaskCommand);

    CGEventPost(kCGHIDEventTap, cmdd);
    CGEventPost(kCGHIDEventTap, tilded);
    CGEventPost(kCGHIDEventTap, tildeu);
    CGEventPost(kCGHIDEventTap, cmdu);

    CFRelease(cmdd);
    CFRelease(cmdu);
    CFRelease(tilded);
    CFRelease(tildeu);
    CFRelease(src);
    
    //setTimeout trigger LeftArrow key (go back one window)
    if (numWindows < 2) return;//(ONLY in case of multiple windows) so you're not always awkwardly focused on second window
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * MINIMAL_DELAY * 0.86), dispatch_get_main_queue(), ^(void){
        triggerKeycode(123);
    });
}
void AltTabHide(AppDelegate* app) {
    if (!app->targetApp || [app->targetApp isEqual:@""]) return;
    triggerEscape(app);
    [app->targetApp setString:@""];
}

int DEFAULTFINDERSUBPROCESSES = 7; //from my experience, after you relaunch, and move from 0 windows (1 process, since finder is ALWAYS running) to 1 window, it's usually 1windowprocess + 7 subprocesses (8 processes for 1 window     OR     1 / 7 processes for 0 windows)
void onLogin(AppDelegate* app) {
    app->numFinderProcesses = [[appInfo(@"Finder") valueForKey:@"numWindows"] intValue]; //in case no. of subprocesses not the same as default (can change after long enough w/o relaunching 💩)
    if (app->numFinderProcesses == 1) app->numFinderProcesses = DEFAULTFINDERSUBPROCESSES; //finder only ever has <7 after login/relaunch
}


//AppDelegate / Lifecycle / Interval Timer
int tickCounter = 0;
@interface AppDelegate ()
@property (strong) IBOutlet NSWindow *window;
@end

@implementation AppDelegate
@synthesize isMenuItemChecked;
- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    onLogin(self);
    appAliases = @{
        @"Visual Studio Code": @"Code",
        @"Adobe Lightroom Classic": @"Lightroom Classic",
        @"iTerm": @"iTerm2"
    };
    targetApp = [NSMutableString stringWithString:@""];
    //get dock's current running process id & orientation & AlTabPID
    dockPos = getDockPosition();
    dockPID = getPID(@"com.apple.dock"); //todo: refresh dockPID every x or so?
    overlayPID = getPID(@"com.lwouis.alt-tab-macos");
    
    //interval Timer @ x seconds, check to render something / stop rendering when mouse enters/leaves the dock
    _systemWideAccessibilityObject = AXUIElementCreateSystemWide();
    timer = [NSTimer scheduledTimerWithTimeInterval:TICK_DELAY
                                             target:self
                                           selector:@selector(timerTick:)
                                           userInfo:nil
                                            repeats:YES];
    appVersion = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSLog(@"timer started");
}
- (void)timerTick: (NSTimer*) arg {
    //check if we need to update overlayPID, dockPos
    const int UPDATE_NUM_TICKS = (DOCKPOS_DELAY * 60) / TICK_DELAY;
    if (tickCounter && tickCounter % UPDATE_NUM_TICKS == 0) {
        dockPos = getDockPosition();
        overlayPID = getPID(@"com.lwouis.alt-tab-macos");
    }
    tickCounter++;
    
    //get mouse location
    NSPoint mouseLocation = [NSEvent mouseLocation];
    CGPoint carbonPoint = carbonPointFrom(mouseLocation);
            
    //copy stuff to vars from mouseLocation:  elementUnderCursor, axTitle, axIsApplicationRunning, axPID
    AXUIElementRef elementUnderCursor = NULL;
    AXUIElementCopyElementAtPosition(self->_systemWideAccessibilityObject, carbonPoint.x, carbonPoint.y, &elementUnderCursor);
    NSString *axTitle = nil;
    AXUIElementCopyAttributeValue(elementUnderCursor, kAXTitleAttribute, (void *)&axTitle);
    axTitle = appAliases[axTitle] ? appAliases[axTitle] : axTitle; //app's with alias work weird (eg: VScode = Code)
    NSNumber *axIsApplicationRunning;
    AXUIElementCopyAttributeValue(elementUnderCursor, kAXIsApplicationRunningAttribute, (void *)&axIsApplicationRunning);
    pid_t axPID;
    AXUIElementGetPid(elementUnderCursor, &axPID);
    
    if ([axTitle isEqual:@"Friendly Streaming"]) return AltTabHide(self); //apps that don't produce windows previews/windows are under different names //todo: create a dictionary w/ more apps?
    
    //does contextMenu exist?
    NSString *role;
    bool showingContextMenu = NO;
    AXUIElementCopyAttributeValue(elementUnderCursor, kAXRoleAttribute, (void*)&role);
    if ([role isEqual:@"AXMenuItem"] || [role isEqual:@"AXMenu"]) showingContextMenu = YES;
    if (!showingContextMenu) {
        //check if there is an open AXMenu @ testPoint next to the mouseLocation (DockLeft +x, DockRight -x, DockBottom -y)
        NSString *testPointRole;
        AXUIElementRef elementNextToCursor = NULL;
        int multiplierX = [dockPos isEqual:@"left"] || [dockPos isEqual:@"right"] ? ([dockPos isEqual:@"left"] ? 1 : -1) : 0;
        int multiplierY = [dockPos isEqual:@"bottom"] ? -1 : 0;
        int testPointX = carbonPoint.x + multiplierX * CONTEXTDISTANCE;
        int testPointY = carbonPoint.y + multiplierY * CONTEXTDISTANCE;
        AXUIElementCopyElementAtPosition(self->_systemWideAccessibilityObject, testPointX, testPointY, &elementNextToCursor);
        AXUIElementCopyAttributeValue(elementNextToCursor, kAXRoleAttribute, (void*)&testPointRole);
        if ([testPointRole isEqual:@"AXMenuItem"] || [testPointRole isEqual:@"AXMenu"]) {
            showingContextMenu = YES;
            [targetApp setString:@""]; //so when contextmenu is closed, preview immediately brought back
        }
    }

    
    //showOverlay logic
    bool showOverlay = axPID != dockPID || [axIsApplicationRunning intValue] == 0 ? NO : YES;
    int numWindows = 0;
    if (showOverlay) { //only calc appInfo if mouse is on dock/dock app icon
        NSDictionary* info = appInfo(axTitle);
        numWindows = [[info valueForKey:@"numWindows"] intValue];
        isMinimized = [info[@"isMinimized"] boolValue];
        isHidden = [info[@"isHidden"] boolValue];
        // yes or no
        if (numWindows == 0 || ((numWindows == 1 || numWindows == numFinderProcesses) && [axTitle isEqual:@"Finder"])) showOverlay = NO; //handle finder's weird window subprocesses (Always on)
    }

    //show / hide
    if (showingContextMenu || axPID == overlayPID) return; //maintain overlay showing / hidden
    if (showOverlay) AltTabShow(axTitle, numWindows, self);
    else AltTabHide(self);

    wasHidden = isHidden;
    wasMinimized = isMinimized;
}
- (void)dealloc {//    [super dealloc]; //todo: why doesn't this work
    [timer invalidate];
    timer = nil;
    if (_systemWideAccessibilityObject) CFRelease(_systemWideAccessibilityObject);
}
- (void) awakeFromNib {
    menuItemCheckBox.state = YES; //default, //todo: save pref to json file & load here
    statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength: NSSquareStatusItemLength];
    [[statusItem button] setImage:[NSImage imageNamed:@"MenuIcon"]];
    [statusItem setMenu:menu];
    [statusItem setVisible:menuItemCheckBox.state]; //without this, could get stuck not showing...?
}
- (IBAction) preferences:(id)sender {
    [NSApp activateIgnoringOtherApps:YES];
    [_window makeKeyAndOrderFront:nil];
    if (!mostCurrentVersion)
        mostCurrentVersion = getCurrentVersion();
    [[appVersionRef cell] setTitle:[@"v" stringByAppendingString:appVersion]];
    [[updateRemindRef cell] setTitle: mostCurrentVersion == NULL ? @"No internet; Update check failed" : (mostCurrentVersion == appVersion) ? @"You're on the latest release." : [@"Version " stringByAppendingString: [mostCurrentVersion stringByAppendingString: @" has been released. You should update soon."]]];
}
- (IBAction) quit:(id)sender {
    [NSApp terminate:nil];
}
- (IBAction)toggleMenuItem:(id)sender {
    [statusItem setVisible:isMenuItemChecked];
}
@end
