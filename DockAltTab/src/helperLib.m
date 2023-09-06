//
//  helperLib.m
//  DockAltTab
//
//  Created by Steven G on 5/9/22.
//

#import "helperLib.h"

@implementation helperLib
+ (void) activateWindow: (NSWindow*) window {
    [NSApp activateIgnoringOtherApps: YES];
    [window makeKeyAndOrderFront: nil];
}
/* https://stackoverflow.com/questions/15305845/how-can-a-mac-gui-app-relaunch-itself-without-using-sparkle */
+ (void) restartApp {
    // Get the path to the current running app executable
    NSBundle* mainBundle = [NSBundle mainBundle];
    NSString* executablePath = [mainBundle executablePath];
    const char* execPtr = [executablePath UTF8String];

#if ATEXIT_HANDLING_NEEDED
    // Get the pid of the parent process
    pid_t originalParentPid = getpid();

    // Fork a child process
    pid_t pid = fork();
    if (pid != 0) // Parent process - exit so atexit() is called
    {
        exit(0);
    }

    // Now in the child process

    // Wait for the parent to die. When it does, the parent pid changes.
    while (getppid() == originalParentPid)
    {
        usleep(250 * 1000); // Wait .25 second
    }
#endif

    // Do the relaunch
    execl(execPtr, execPtr, NULL);
}
@end
