//
//  prefs.h
//  Dock Profiles
//
//  Created by Steven G on 9/8/23.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "app.h"

NS_ASSUME_NONNULL_BEGIN

@interface prefs : NSObject
+ (NSDictionary*) setDefaults: (NSDictionary*) defaultsDict;
+ (NSDictionary*) load;

+ (void) removePref: (NSString*) key;

+ (NSArray*) getArrayPref: (NSString*) key;
+ (NSDictionary*) getDictPref: (NSString*) key;
+ (NSString*) getStringPref: (NSString*) key;
+ (BOOL) getBoolPref: (NSString*) key;
+ (int) getIntPref: (NSString*) key;
+ (double) getDoublePref: (NSString*) key;
+ (float) getFloatPref: (NSString*) key;

+ (NSArray*) setArrayPref: (NSString*) key : (NSArray*) val;
+ (NSDictionary*) setDictPref: (NSString*) key : (NSDictionary*) val;
+ (NSString*) setStringPref: (NSString*) key : (NSString*) val;
+ (BOOL) setBoolPref: (NSString*) key : (BOOL) val;
+ (int) setIntPref: (NSString*) key : (int) val;
+ (double) setDoublePref: (NSString*) key : (double) val;
+ (float) setFloatPref: (NSString*) key : (float) val;

@end

NS_ASSUME_NONNULL_END
