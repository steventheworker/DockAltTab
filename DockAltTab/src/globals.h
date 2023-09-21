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
void setTimeout(void(^cb)(void), int delay);
void clearTimeout(dispatch_block_t blockRef);
#endif /* globals_h */
