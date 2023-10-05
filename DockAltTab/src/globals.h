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
void clearTimeout(int i);
#endif /* globals_h */
