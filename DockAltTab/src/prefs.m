//
//  prefs.m
//  Dock Profiles
//
//  Created by Steven G on 9/8/23.
//

#import "prefs.h"

NSDictionary* defaults = nil;

@implementation prefs
+ (NSDictionary*) setDefaults: (NSDictionary*) defaultsDict {
    defaults = defaultsDict;
    return [self load];
}
+ (NSDictionary*) load { //load all prefs into dictionary (manually)
    NSMutableDictionary* ret = [NSMutableDictionary dictionary];
    for (NSString* key in defaults) {
        NSValue* val = [[NSUserDefaults standardUserDefaults] valueForKey: key];
        ret[key] = val ? val : defaults[key];
    }
    return ret;
}
+ (void) removePref: (NSString*) key {[[NSUserDefaults standardUserDefaults] removeObjectForKey: key];}
//grabs pref & use default value if unset
+ (NSArray*) getArrayPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? defaults[key] : val;}
+ (NSDictionary*) getDictPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? defaults[key] : val;}
+ (NSString*) getStringPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? defaults[key] : val;}
+ (BOOL) getBoolPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? [defaults[key] boolValue] : [val boolValue];}
+ (int) getIntPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? [defaults[key] intValue] : [val intValue];}
+ (double) getDoublePref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? [defaults[key] doubleValue] : [val doubleValue];}
+ (float) getFloatPref: (NSString*) key {id val = [[NSUserDefaults standardUserDefaults] valueForKey: key];return (val == nil) ? [defaults[key] floatValue] : [val floatValue];}

+ (NSArray*) setArrayPref: (NSString*) key : (NSArray*) val {[[NSUserDefaults standardUserDefaults] setObject: val forKey: key];return val;}
+ (NSDictionary*) setDictPref: (NSString*) key : (NSDictionary*) val {[[NSUserDefaults standardUserDefaults] setObject: val forKey: key];return val;}
+ (NSString*) setStringPref: (NSString*) key : (NSString*) val {[[NSUserDefaults standardUserDefaults] setObject: val forKey: key];return val;}
+ (BOOL) setBoolPref: (NSString*) key : (BOOL) val {[[NSUserDefaults standardUserDefaults] setBool: val forKey: key];return val;}
+ (int) setIntPref: (NSString*) key : (int) val {[[NSUserDefaults standardUserDefaults] setInteger: val forKey: key];return val;}
+ (double) setDoublePref: (NSString*) key : (double) val {[[NSUserDefaults standardUserDefaults] setDouble: val forKey: key];return val;}
+ (float) setFloatPref: (NSString*) key : (float) val {[[NSUserDefaults standardUserDefaults] setFloat: val forKey: key];return val;}

@end
