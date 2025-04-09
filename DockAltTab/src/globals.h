//
//  globals.h
//  DockAltTab
//
//  Created by Steven G on 10/21/22.
//

#ifndef globals_h
#define globals_h

#include <stdio.h>
#include <Cocoa/Cocoa.h>
int setTimeout(void(^cb)(void), int delay);
int clearTimeout(int i);
void throw(NSString* message, ...);
void hideRunningApp(NSRunningApplication* app, void(^cb)(void));
void unhideRunningApp(NSRunningApplication* app, void(^cb)(void));
void activateRunningApp(NSRunningApplication* app, void(^cb)(void));
#endif /* globals_h */
