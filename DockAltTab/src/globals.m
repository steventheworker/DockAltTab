//
//  globals.c    -    
//  DockAltTab
//
//  Created by Steven G on 10/21/22.
//

#include "globals.h"
#import <Foundation/Foundation.h>

//void GSPrintTest(void) {
//  NSLog(@"test");
//}
void setTimeout(void(^cb)(void), int delay) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * (delay)), dispatch_get_main_queue(), cb);
}
