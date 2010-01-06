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

#define LUA_OBJC_TYPE_BITFIELD 'b'
#define LUA_OBJC_TYPE_C99_BOOL 'B'
#define LUA_OBJC_TYPE_CHAR 'c'
#define LUA_OBJC_TYPE_UNSIGNED_CHAR 'C'
#define LUA_OBJC_TYPE_DOUBLE 'd'
#define LUA_OBJC_TYPE_FLOAT 'f'
#define LUA_OBJC_TYPE_INT 'i'
#define LUA_OBJC_TYPE_UNSIGNED_INT 'I'
#define LUA_OBJC_TYPE_LONG 'l'
#define LUA_OBJC_TYPE_UNSIGNED_LONG 'L'
#define LUA_OBJC_TYPE_LONG_LONG 'q'
#define LUA_OBJC_TYPE_UNSIGNED_LONG_LONG 'Q'
#define LUA_OBJC_TYPE_SHORT 's'
#define LUA_OBJC_TYPE_UNSIGNED_SHORT 'S'
#define LUA_OBJC_TYPE_VOID 'v'
#define LUA_OBJC_TYPE_UNKNOWN '?'

#define LUA_OBJC_TYPE_ID '@'
#define LUA_OBJC_TYPE_CLASS '#'
#define LUA_OBJC_TYPE_POINTER '^'
#define LUA_OBJC_TYPE_STRING '*'

#define LUA_OBJC_TYPE_UNION '('
#define LUA_OBJC_TYPE_UNION_END ')'
#define LUA_OBJC_TYPE_ARRAY '['
#define LUA_OBJC_TYPE_ARRAY_END ']'
#define LUA_OBJC_TYPE_STRUCT '{'
#define LUA_OBJC_TYPE_STRUCT_END '}'
#define LUA_OBJC_TYPE_SELECTOR ':'

#define LUA_OBJC_TYPE_IN 'n'
#define LUA_OBJC_TYPE_INOUT 'N'
#define LUA_OBJC_TYPE_OUT 'o'
#define LUA_OBJC_TYPE_BYCOPY 'O'
#define LUA_OBJC_TYPE_CONST 'r'
#define LUA_OBJC_TYPE_BYREF 'R'
#define LUA_OBJC_TYPE_ONEWAY 'V'


NSString *LUSelectorNameFromLuaName(const char *name)
{
  return [[NSString stringWithUTF8String:name] stringByReplacingOccurrencesOfString:@"_" withString:@":"];
}

static void lua_objc_pushid(lua_State *state, id object);

static id lua_objc_luatype_to_id(lua_State *L, int index) 
{
  switch (lua_type(L, index)) {
    case LUA_TNIL:
      return [NSNull null];
    case LUA_TNUMBER:
      return [NSNumber numberWithDouble:lua_tonumber(L, index)];
    case LUA_TBOOLEAN:
      return [NSNumber numberWithBool:(BOOL)lua_toboolean(L, index)];
    case LUA_TSTRING:
      return [NSString stringWithUTF8String:lua_tostring(L, index)];
    case LUA_TUSERDATA: {
      id *userdata = lua_touserdata(L, index);
      return *userdata;
    }
    default:
      lua_pushstring(L, [[NSString stringWithFormat:@"converting Lua type '%s' to Objective-C type is not supported.", lua_typename(L, lua_type(L, index))] UTF8String]);
      lua_error(L);
      return nil;
  }
}

// Hacky defines

#define set_arg(type, value, i, inv) \
          do { type v = (type)value; [inv setArgument:&v atIndex:i]; } while(0)

#define ensure_lua_type(ltype, L, index) \
          do { if (lua_type(L, index) != ltype) { \
                 lua_pushstring(L, [[NSString stringWithFormat:@"argument %d of method '%@' requires '%s', given '%s'.", index-2, NSStringFromSelector(selector), lua_typename(L, ltype), lua_typename(L, lua_type(L, index))] UTF8String]); \
                 lua_error(L); return 0; } \
          } while(0)

#define get_return_value(type) \
          type _value; [inv getReturnValue:&_value]

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
    return 0;
  }  
  id object = *objptr;
  
  NSMethodSignature *sig = [object methodSignatureForSelector:selector];
  if (!sig) {
    NSString *error = [NSString stringWithFormat:@"method '%@' not found in object '%@'.", NSStringFromSelector(selector), [object description]];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
    return 0;
  }

  NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
  [inv setTarget:object];
  [inv setSelector:selector];

  // Fill arguments
  int i = 2;
  int index = 3;
  int numberOfArguments = [sig numberOfArguments];
  
  while (i < numberOfArguments && !lua_isnil(state, index)) {

    switch ([sig getArgumentTypeAtIndex:i][0]) {
      case LUA_OBJC_TYPE_ID:
      case LUA_OBJC_TYPE_CLASS: {
        id obj = lua_objc_luatype_to_id(state, index);
        [inv setArgument:&obj atIndex:i];
        break;
      }
      case LUA_OBJC_TYPE_CHAR: {
        switch(lua_type(state, index)) {
          case LUA_TBOOLEAN: set_arg(char, (char)lua_toboolean(state, index), i, inv); break;
          case LUA_TNUMBER: set_arg(char, (char)lua_tointeger(state, index), i, inv); break;
          default: 
            ensure_lua_type(LUA_TBOOLEAN, state, index);
            ensure_lua_type(LUA_TNUMBER, state, index);
        }
        break;
      }
      case LUA_OBJC_TYPE_UNSIGNED_CHAR: {
        switch(lua_type(state, index)) {
          case LUA_TBOOLEAN: set_arg(unsigned char, (unsigned char)lua_toboolean(state, index), i, inv); break;
          case LUA_TNUMBER: set_arg(unsigned char, (unsigned char)lua_tointeger(state, index), i, inv); break;
          default:
            ensure_lua_type(LUA_TBOOLEAN, state, index);
            ensure_lua_type(LUA_TNUMBER, state, index);
        }
        break;
      }
      case LUA_OBJC_TYPE_C99_BOOL:
        ensure_lua_type(LUA_TBOOLEAN, state, index);
        set_arg(_Bool, lua_toboolean(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_SHORT:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(short, lua_tointeger(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_SHORT:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(unsigned short, lua_tointeger(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_INT:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(int, lua_tointeger(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_INT:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(unsigned int, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_LONG:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(long, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(unsigned long, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_LONG_LONG:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(long long, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(unsigned long long, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_DOUBLE:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(double, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_FLOAT:
        ensure_lua_type(LUA_TNUMBER, state, index);
        set_arg(float, lua_tonumber(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_STRING:
        ensure_lua_type(LUA_TSTRING, state, index);
        set_arg(const char*, lua_tostring(state, index), i, inv);
        break;
      case LUA_OBJC_TYPE_POINTER:
        ensure_lua_type(LUA_TUSERDATA, state, index);
        set_arg(void*, lua_touserdata(state, index), i, inv);
        break;
      default: {
        NSString *error = [NSString stringWithFormat:@"argument %d of type '%s' is not supported (calling '%@' for object '%@').", i-1, [sig getArgumentTypeAtIndex:i], NSStringFromSelector(selector), [object description]];
        lua_pushstring(state, [error UTF8String]);
        lua_error(state); return 0;
      }
    }    
    i++;
    index++;
  }
  [inv retainArguments];  
  
  [inv invoke];
  
  const char *returnType = [sig methodReturnType];
  switch (returnType[0]) {
    case LUA_OBJC_TYPE_CLASS:
    case LUA_OBJC_TYPE_ID: {
      get_return_value(id);
      lua_objc_pushid(state, _value);
      break;      
    }
    case LUA_OBJC_TYPE_CHAR: {
      get_return_value(char);
      lua_pushinteger(state, _value);
    }
    case LUA_OBJC_TYPE_UNSIGNED_CHAR: {
      get_return_value(unsigned char);
      lua_pushinteger(state, _value);
    }
    case LUA_OBJC_TYPE_C99_BOOL: {     
      get_return_value(_Bool);
      lua_pushboolean(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_SHORT: {
      get_return_value(short);
      lua_pushinteger(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_UNSIGNED_SHORT: {
      get_return_value(unsigned short);
      lua_pushinteger(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_INT: {
      get_return_value(int);
      lua_pushinteger(state, _value);      
      break;
    }
    case LUA_OBJC_TYPE_UNSIGNED_INT: {      
      get_return_value(unsigned int);
      lua_pushinteger(state, _value);      
      break;
    }
    case LUA_OBJC_TYPE_LONG: {
      get_return_value(long);
      lua_pushnumber(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_UNSIGNED_LONG: {
      get_return_value(unsigned long);
      lua_pushnumber(state, _value);      
      break;
    }
    case LUA_OBJC_TYPE_LONG_LONG: {
      get_return_value(long long);
      lua_pushnumber(state, _value);      
      break;
    }
    case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG: {
      get_return_value(unsigned long long);
      lua_pushnumber(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_DOUBLE: {
      get_return_value(double);
      lua_pushnumber(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_FLOAT: {
      get_return_value(float);
      lua_pushnumber(state, _value);
      break;
    }
    case LUA_OBJC_TYPE_STRING: {
      const char *value = malloc([[inv methodSignature] methodReturnLength]);
      [inv getReturnValue:&value];
      lua_pushstring(state, value);
      break;
    }
    default: {
      NSString *error = [NSString stringWithFormat:@"unsupported return type '%s' (calling '%@' for object '%@').", returnType, NSStringFromSelector(selector), [object description]];
      lua_pushstring(state, [error UTF8String]);
      lua_error(state); return 0;
    }
  }
  return 1;
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
