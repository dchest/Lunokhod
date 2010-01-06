//
//  Lunokhod.m
//  Lunokhod
//
//  Created by Dmitry Chestnykh on 05.01.10.
//  Copyright 2010 Coding Robots. All rights reserved.
//

#import "Lunokhod.h"
#import "lauxlib.h"
#import "lualib.h"

NSString *LUSelectorNameFromLuaName(const char *name)
{
  return [[NSString stringWithUTF8String:name] stringByReplacingOccurrencesOfString:@"_" withString:@":"];
}

static void lua_objc_pushid(lua_State *state, id object);

static int lua_objc_callselector(lua_State *state)
{
  SEL *selptr = lua_touserdata(state, 1);
  SEL selector = *selptr;

  id *objptr = lua_touserdata(state, 2);
  if (!objptr) {
    // Second argument is nil, so there was no object, and the objptr is actually a selector
    NSString *error = [NSString stringWithFormat:@"arguments for '%@' require object (use ':' instead of '.' to call methods).", NSStringFromSelector(selector)];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
  }  
  id object = *objptr;

  NSMethodSignature *sig = [object methodSignatureForSelector:selector];
  if (!sig) {
    NSString *error = [NSString stringWithFormat:@"method '%@' not found in object '%@'.", NSStringFromSelector(selector), [object description]];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
  }

  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setTarget:object];
  [inv setSelector:selector];
//  int i = 2;
//  for (id argument in arguments) {
//    [inv setArgument:&argument atIndex:i];
//    i++;
//  }
//  [inv retainArguments];
  [inv invoke];
  id result = nil;
  [inv getReturnValue:&result];
  lua_objc_pushid(state, result);
  return 1;
  //TODO cache IMP?
}

static int lua_objc_id_tostring(lua_State *state)
{
  id *objptr = lua_touserdata(state, -1);
  lua_pushstring(state, [[*objptr description] UTF8String]);
  return 1;
}

static int lua_objc_pushselector(lua_State *state)
{
  SEL selector = NSSelectorFromString(LUSelectorNameFromLuaName(lua_tostring(state, -1)));
  SEL *p = lua_newuserdata(state, sizeof(SEL));
  *p = selector;
  // Create metatable for selector
	lua_newtable(state);
  lua_pushstring(state, "__call");
  lua_pushcfunction(state, lua_objc_callselector);
  lua_settable(state, -3);
  lua_setmetatable(state, -2);
  return 1;
}

static int lua_objc_releaseid(lua_State *state)
{
  id *objptr = lua_touserdata(state, -1);
  if (objptr) {
    [*objptr release];
    *objptr = nil;
  }
  return 0;
}

static void lua_objc_pushid(lua_State *state, id object)
{
  id *p = lua_newuserdata(state, sizeof(id));
  *p = object;
  // Create metatable for id
  lua_newtable(state);
  lua_pushstring(state, "__index");
  lua_pushcfunction(state, lua_objc_pushselector);
  lua_settable(state, -3);
  lua_pushstring(state, "__tostring");
  lua_pushcfunction(state, lua_objc_id_tostring);
  lua_settable(state, -3);
  if ([NSGarbageCollector defaultCollector] == nil) {
    lua_pushstring(state, "__gc");
    lua_pushcfunction(state, lua_objc_releaseid);
    lua_settable(state, -3);
  }
  lua_setmetatable(state, -2);    
}

static int lua_objc_lookup_class(lua_State *state)
{
  Class klass = NSClassFromString([NSString stringWithUTF8String:lua_tostring(state,-1)]);
  if (klass != nil)
    lua_objc_pushid(state, klass);    
  else
    lua_pushnil(state);
  return 1;  
}

@implementation Lunokhod

- (id)init
{
  if (![super init])
    return nil;
  luaState_ = lua_open();

  lua_gc(luaState_, LUA_GCSTOP, 0);  // stop collector during initialization
  luaL_openlibs(luaState_);  // open libraries

  // Table objc
  lua_newtable(luaState_);
  lua_pushstring(luaState_, "class");
  
  // Table for objc.class
  lua_newtable(luaState_);
  // Metatable for objc.class
  lua_newtable(luaState_);
  lua_pushstring(luaState_, "__index");
  lua_pushcfunction(luaState_, lua_objc_lookup_class);
  lua_settable(luaState_, -3);
  lua_setmetatable(luaState_, -2);
  // now we have class and our new table in stack
  // objc.class = {our table}
  lua_settable(luaState_, -3); 
  
  lua_setglobal(luaState_, "objc");

  lua_gc(luaState_, LUA_GCRESTART, 0); // restart collector  
  return self;
}

- (void)dealloc
{
  lua_gc(luaState_, LUA_GCCOLLECT, 0);
  lua_close(luaState_);
  [super dealloc];
}

- (void)finalize
{
  lua_close(luaState_);
  [super finalize];
}


- (void)logCurrentError
{
  // Get error from stack and output it
  if (!lua_isnil(luaState_, -1))
    NSLog(@"Lunokhod error: %s", lua_tostring(luaState_, -1));
  else {
    NSLog(@"Lunokhod error: unknown");
  }
  //[self doString:@"debug.traceback()"];
}

- (BOOL)loadFile:(NSString *)filename withFunctionName:(NSString *)functionName
{
  BOOL result = YES;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (luaL_loadfile(luaState_, [filename UTF8String]) != 0) {
    [self logCurrentError];
    result = NO;
  } else {
    // Push to stack as function
    lua_setglobal(luaState_, [functionName UTF8String]);
  }
  
  [pool drain];
  return result;
}

- (BOOL)doFile:(NSString *)filename
{
  BOOL result = YES;
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  
  if (luaL_dofile(luaState_, [filename UTF8String]) != 0) {
    [self logCurrentError];
    result = NO;
  }

  [pool drain];
  return result;
}

- (BOOL)loadString:(NSString *)string withFunctionName:(NSString *)functionName
{
  if (luaL_loadstring(luaState_, [string UTF8String]) == 0) {
    // Push to stack as function
    lua_setglobal(luaState_, [functionName UTF8String]); 
    return YES;
  } else {
    [self logCurrentError];
    return NO;
  }
}


- (BOOL)doString:(NSString *)string
{
  if (luaL_dostring(luaState_, [string UTF8String]) == 0) {
    return YES;
  } else {
    [self logCurrentError];
    return NO;
  }
}

@end
