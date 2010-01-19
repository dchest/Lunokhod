//
//  Lunokhod.h
//  Lunokhod
//
//  Created by Dmitry Chestnykh on 05.01.10.
//  Copyright 2010 Coding Robots. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "lua.h"

@interface Lunokhod : NSObject {
  lua_State *luaState_;
}
- (BOOL)doString:(NSString *)string;
- (BOOL)doFile:(NSString *)filename;
- (BOOL)loadFile:(NSString *)filename withFunctionName:(NSString *)functionName;
- (BOOL)loadString:(NSString *)string withFunctionName:(NSString *)functionName;
- (void)addPackagePath:(NSString *)path;

@end
