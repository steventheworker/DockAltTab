//
//  globals.m    -    globals.c  (error https://stackoverflow.com/questions/25999754/error-message-could-not-build-module-foundation (bryan 's answer))
//  DockAltTab
//
//  Created by Steven G on 10/21/22.
//

#include "globals.h"
#import <Foundation/Foundation.h>

void setTimeout(void(^cb)(void), int delay) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_MSEC * (delay)), dispatch_get_main_queue(), cb);
}
