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
#import <ObjC/runtime.h>

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


//  We create (and add to registeredClasses) the following proxy objects for every class created in Lua to get luaState when resolving methods
@interface LuaObjcClassProxy : NSObject
{
@public
  Class originalClass;
  lua_State *luaState;
}
@end

@implementation LuaObjcClassProxy

- (id)initWithClass:(Class)klass luaState:(lua_State *)state
{
  if (![super init])
    return nil;
  originalClass = klass;
  luaState = state;
  return self;
}

@end

// Used to keep track of classes created in Lua.

static NSMapTable *registeredClasses = nil;

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

static id lua_objc_toid(lua_State *state, int index)
{
  id *objptr = lua_touserdata(state, index);
  if (!objptr)
    return nil;
  else
    return *objptr;
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

void find_lua_function_for_method(lua_State *state, id obj, SEL selector);

static int lua_objc_callselector(lua_State *state)
{
  SEL *selptr = lua_touserdata(state, 1);
  SEL selector = *selptr;

  id object = lua_objc_toid(state, 2);
  if (!object) {
    // Second argument is nil, so there was no object, and the objptr is actually a selector
    NSString *error = [NSString stringWithFormat:@"arguments for '%@' require object (use ':' instead of '.' to call methods).", NSStringFromSelector(selector)];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
    return 0;
  }

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

  // Convert and fill arguments
  int objcIndex = 2;
  int luaIndex = 3;
  int numberOfArguments = [sig numberOfArguments];
  void *buffer = NULL; // for array and struct

  while (objcIndex < numberOfArguments) {

    if (lua_isnil(state, luaIndex) || lua_isnone(state, luaIndex)) {
      id null = nil;
      [inv setArgument:&null atIndex:objcIndex];
      objcIndex++;
      luaIndex++;
      continue;
    }

    switch ([sig getArgumentTypeAtIndex:objcIndex][0]) {
      case LUA_OBJC_TYPE_ID:
      case LUA_OBJC_TYPE_CLASS: {
        id obj = lua_objc_luatype_to_id(state, luaIndex);
        [inv setArgument:&obj atIndex:objcIndex];
        break;
      }
      case LUA_OBJC_TYPE_CHAR: {
        switch(lua_type(state, luaIndex)) {
          case LUA_TBOOLEAN: set_arg(char, (char)lua_toboolean(state, luaIndex), objcIndex, inv); break;
          case LUA_TNUMBER: set_arg(char, (char)lua_tointeger(state, luaIndex), objcIndex, inv); break;
          default:
            ensure_lua_type(LUA_TBOOLEAN, state, luaIndex);
            ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        }
        break;
      }
      case LUA_OBJC_TYPE_UNSIGNED_CHAR: {
        switch(lua_type(state, luaIndex)) {
          case LUA_TBOOLEAN: set_arg(unsigned char, (unsigned char)lua_toboolean(state, luaIndex), objcIndex, inv); break;
          case LUA_TNUMBER: set_arg(unsigned char, (unsigned char)lua_tointeger(state, luaIndex), objcIndex, inv); break;
          default:
            ensure_lua_type(LUA_TBOOLEAN, state, luaIndex);
            ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        }
        break;
      }
      case LUA_OBJC_TYPE_C99_BOOL:
        ensure_lua_type(LUA_TBOOLEAN, state, luaIndex);
        set_arg(_Bool, lua_toboolean(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_SHORT:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(short, lua_tointeger(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_SHORT:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(unsigned short, lua_tointeger(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_INT:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(int, lua_tointeger(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_INT:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(unsigned int, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_LONG:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(long, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(unsigned long, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_LONG_LONG:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(long long, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(unsigned long long, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_DOUBLE: {
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(double, lua_tonumber(state, luaIndex), objcIndex, inv);
        /*NSUInteger length = [sig frameLength];
        double d = lua_tonumber(state, luaIndex);
        buffer = malloc(length);
        memcpy(buffer, &d, length);
        [inv setArgument:buffer atIndex:objcIndex];*/
        break;
      }
      case LUA_OBJC_TYPE_FLOAT:
        ensure_lua_type(LUA_TNUMBER, state, luaIndex);
        set_arg(float, lua_tonumber(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_STRING:
        ensure_lua_type(LUA_TSTRING, state, luaIndex);
        set_arg(const char*, lua_tostring(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_POINTER:
        ensure_lua_type(LUA_TUSERDATA, state, luaIndex);
        set_arg(void*, lua_touserdata(state, luaIndex), objcIndex, inv);
        break;
      case LUA_OBJC_TYPE_ARRAY:
      case LUA_OBJC_TYPE_STRUCT:
      case LUA_OBJC_TYPE_SELECTOR:
        ensure_lua_type(LUA_TUSERDATA, state, luaIndex);
        NSUInteger length = [sig frameLength];
        buffer = malloc(length);
        memcpy(buffer, lua_touserdata(state, luaIndex), length);
        [inv setArgument:buffer atIndex:objcIndex];
        break;
      default: {
        NSString *error = [NSString stringWithFormat:@"argument %d of type '%s' is not supported (calling '%@' for object '%@').", objcIndex-1, [sig getArgumentTypeAtIndex:objcIndex], NSStringFromSelector(selector), [object description]];
        lua_pushstring(state, [error UTF8String]);
        lua_error(state); return 0;
      }
    }
    objcIndex++;
    luaIndex++;
  }
  [inv invoke];

  if (buffer != NULL)
    free(buffer);

  // Convert return types
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
      break;
    }
    case LUA_OBJC_TYPE_UNSIGNED_CHAR: {
      get_return_value(unsigned char);
      lua_pushinteger(state, _value);
      break;
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
    case LUA_OBJC_TYPE_ARRAY:
    case LUA_OBJC_TYPE_STRUCT:
    case LUA_OBJC_TYPE_SELECTOR: {
      char *value = lua_newuserdata(state, [[inv methodSignature] methodReturnLength]);
      [inv getReturnValue:(char *)value];
      break;
    }
    case LUA_OBJC_TYPE_VOID:
      return 0; // no return
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
  id object = lua_objc_toid(state, -1);
  lua_pushstring(state, [[object description] UTF8String]);
  return 1;
}

static int lua_objc_direct_call(lua_State *state)
{
  SEL *selptr = lua_touserdata(state, 1);
  SEL selector = *selptr;
  id object = lua_objc_toid(state, 2);
  if (!object) {
    // Second argument is nil, so there was no object, and the objptr is actually a selector
    NSString *error = [NSString stringWithFormat:@"arguments for '%@' require object (use ':' instead of '.' to call methods).", NSStringFromSelector(selector)];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
    return 0;
  }
  if (![object respondsToSelector:selector]) {
    NSString *error = [NSString stringWithFormat:@"method '%@' not found in object '%@'.", NSStringFromSelector(selector), [object description]];
    lua_pushstring(state, [error UTF8String]);
    lua_error(state);
    return 0;
  }
  IMP imp = [object methodForSelector:selector];
  return (NSInteger)imp(object, selector, state);
}

static int lua_objc_pushselector(lua_State *state)
{
  char *selName = strdup(lua_tostring(state, -1));
  BOOL isDirectCall = NO;

  if (selName[0] == 'l' && selName[1] == 'u' && selName[2] == 'a' && selName[3] == '_') {
    // Selectors in format lua_something_() will be handled by lua_objec_direct_call(), which calls [obj lua_something:lua_State]
    isDirectCall = YES;
    selName[strlen(selName)-1] = ':';
  } else {
    // Convert selector name from one_two_three_ to one:two:three:
    for (int i = 0; selName[i] != '\0'; i++) {
      if (selName[i] == '_')
        selName[i] = ':';
    }
  }

  SEL *selptr = lua_newuserdata(state, sizeof(SEL));
  *selptr = sel_registerName(selName);
  free(selName);
  // Create metatable for selector
	lua_newtable(state);
  lua_pushstring(state, "__call");
  if (!isDirectCall)
    lua_pushcfunction(state, lua_objc_callselector);
  else
    lua_pushcfunction(state, lua_objc_direct_call);
  lua_settable(state, -3);
  lua_setmetatable(state, -2);
  return 1;
}

static int lua_objc_releaseid(lua_State *state)
{
  id *objptr = lua_touserdata(state, -1);
  if (objptr) {
    [*objptr release];
    [[NSGarbageCollector defaultCollector] enableCollectorForPointer:*objptr];
    *objptr = nil;
  }
  return 0;
}

static void lua_objc_pushid(lua_State *state, id object)
{
  id *p = lua_newuserdata(state, sizeof(id));
  *p = object;
  [[NSGarbageCollector defaultCollector] disableCollectorForPointer:object];
  // Create metatable for id
  lua_newtable(state);
  lua_pushstring(state, "__index");
  lua_pushcfunction(state, lua_objc_pushselector);
  lua_settable(state, -3);
  lua_pushstring(state, "__tostring");
  lua_pushcfunction(state, lua_objc_id_tostring);
  lua_settable(state, -3);
  lua_pushstring(state, "__gc");
  lua_pushcfunction(state, lua_objc_releaseid);
  lua_settable(state, -3);
  lua_setmetatable(state, -2);
}

static int lua_objc_lookup_class(lua_State *state)
{
  Class klass = objc_getClass(lua_tostring(state,-1));
  if (klass != nil)
    lua_objc_pushid(state, klass);
  else
    lua_pushnil(state);
  return 1;
}

static int lua_objc_newclass(lua_State *state)
{
  const char *className = lua_tostring(state, 1);
  Class superclass = lua_objc_toid(state, 2);
  Class klass = objc_allocateClassPair(superclass, className, 0);
  if (!klass) {
    //lua_pushfstring(state, "class %s cannot be created (probably it already exists).", className);
    //lua_error(state); return 0;
    lua_pushnil(state);
    return 0;
  }
  // Register class in function dispatch
  lua_getglobal(state, "__LUNOKHOD_DISPATCH");
  lua_pushstring(state, className);
  lua_newtable(state);
  lua_settable(state, -3);

  // Call initialization function (3rd argument to this function)
  lua_pushvalue(state, 3);
  lua_objc_pushid(state, klass);
  lua_call(state, 1, 0);
  objc_registerClassPair(klass);
  // Register proxy for klass
  LuaObjcClassProxy *proxy = [[LuaObjcClassProxy alloc] initWithClass:klass luaState:state];
  [registeredClasses setObject:proxy forKey:klass];

  lua_objc_pushid(state, klass);
  return 1;
}

static int lua_objc_rect(lua_State *state)
{
  CGFloat x = lua_tonumber(state, 1);
  CGFloat y = lua_tonumber(state, 2);
  CGFloat w = lua_tonumber(state, 3);
  CGFloat h = lua_tonumber(state, 4);
  NSRect rect = NSMakeRect(x, y, w, h);
  void *p = lua_newuserdata(state, sizeof(rect));
  memcpy(p, &rect, sizeof(rect));
  return 1;
}

static int lua_objc_size(lua_State *state)
{
  CGFloat w = lua_tonumber(state, 1);
  CGFloat h = lua_tonumber(state, 2);
  NSSize sz = NSMakeSize(w, h);
  void *p = lua_newuserdata(state, sizeof(sz));
  memcpy(p, &sz, sizeof(sz));
  return 1;
}

// Finds Lua function for ObjC method and pushes it on top of stack
void find_lua_function_for_method(lua_State *state, id obj, SEL selector)
{
  do {
    lua_getglobal(state, "__LUNOKHOD_DISPATCH");
    lua_pushstring(state, [[obj className] UTF8String]);
    lua_gettable(state, -2);
    lua_getfield(state, -1, [NSStringFromSelector(selector) UTF8String]);
    if (!lua_isnil(state, -1))
      break;
  } while ((obj = [obj superclass]) != nil && ![[obj className] isEqualToString:@"NSObject"]);
}

id invokeLuaFunction(id self, SEL _cmd, ...)
{
  LuaObjcClassProxy *proxy = [registeredClasses objectForKey:[self class]];
  if (proxy == nil) {
    NSLog(@"no proxy for %@", [self class]);
    return 0;
  }
  lua_State *state = proxy->luaState;

  // Find Lua function for this method (in self or superclasses)
  find_lua_function_for_method(state, self, _cmd); // got function on top of stack

  // Push arguments
  lua_objc_pushid(state, self);  // push self first

  Method method = class_getInstanceMethod([self class], _cmd);
  unsigned argNum = method_getNumberOfArguments(method);

  va_list list;
  va_start(list, _cmd);
  char argType;

  for(int i = 2; i < argNum; i++) {
    method_getArgumentType(method, i, &argType, 1);
    switch (argType) {
      case LUA_OBJC_TYPE_VOID:
        lua_pushnil(state);
        break;
      case LUA_OBJC_TYPE_ID:
      case LUA_OBJC_TYPE_CLASS:
        lua_objc_pushid(state, va_arg(list, id));
        break;
      case LUA_OBJC_TYPE_C99_BOOL:
        lua_pushboolean(state, va_arg(list, int));
        break;
      case LUA_OBJC_TYPE_CHAR: /* the following types are promoted to int in list */
      case LUA_OBJC_TYPE_UNSIGNED_CHAR:
      case LUA_OBJC_TYPE_SHORT:
      case LUA_OBJC_TYPE_UNSIGNED_SHORT:
      case LUA_OBJC_TYPE_INT: {
        int n = va_arg(list, int);
        lua_pushnumber(state, n);
        break;
      }
      case LUA_OBJC_TYPE_UNSIGNED_INT:
        lua_pushnumber(state, va_arg(list, unsigned int));
        break;
      case LUA_OBJC_TYPE_LONG:
        lua_pushnumber(state, va_arg(list, long));
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG:
        lua_pushnumber(state, va_arg(list, unsigned long));
        break;
      case LUA_OBJC_TYPE_LONG_LONG:
        lua_pushnumber(state, va_arg(list, long long));
        break;
      case LUA_OBJC_TYPE_UNSIGNED_LONG_LONG:
        lua_pushnumber(state, va_arg(list, unsigned long long));
        break;
      case LUA_OBJC_TYPE_FLOAT: /* float is promoted to double in list */
      case LUA_OBJC_TYPE_DOUBLE: {
        //FIXME va_arg returns 0 for 'double' on x86_64 when called from Lua.
        //I don't know how to fix it.
        //double d = va_arg(list, double);
        //void *addr = list[0].reg_save_area + offset;
        ////list[0].reg_save_area += sizeof(double);
        double d = va_arg(list, double);
        lua_pushnumber(state, d);
        #if __LP64__
        NSLog(@"Lunokhod warning: double types in Lua functions for methods don't work on x86_64 when called from Lua.");
        #endif
        break;
      }
      case LUA_OBJC_TYPE_STRING:
        lua_pushstring(state, va_arg(list, const char *));
        break;
      default: {
        NSString *error = [NSString stringWithFormat:@"argument %d of type '%c' is not supported (calling '%@' for object '%@').", i-1, argType, NSStringFromSelector(_cmd), [self description]];
        lua_pushstring(state, [error UTF8String]);
        lua_error(state); return 0;
      }
    }
  }
  va_end(list);
  char returnType;
  method_getReturnType(method, &returnType, 1);

  if (returnType == LUA_OBJC_TYPE_VOID) {
    lua_call(state, argNum-1, 0);
    return nil;
  }
  else
    lua_call(state, argNum-1, 1);

  // Convert return type to Objective-C
  switch (returnType) {
    case LUA_OBJC_TYPE_CLASS:
    case LUA_OBJC_TYPE_ID:
      return lua_objc_luatype_to_id(state, -1);
      break;
    case LUA_OBJC_TYPE_CHAR:
    case LUA_OBJC_TYPE_UNSIGNED_CHAR:
    case LUA_OBJC_TYPE_SHORT:
    case LUA_OBJC_TYPE_UNSIGNED_SHORT:
    case LUA_OBJC_TYPE_INT:
    case LUA_OBJC_TYPE_LONG: {
      #if __LP64__
      long n;
      #else
      int n;
      #endif
      n = lua_tonumber(state, -1);
      return (void *)n;
    }
    default:
      lua_pushstring(state, "Unsupported return type");
      lua_error(state);
      break;
  }
  return nil;
}

static int lua_objc_addmethod(lua_State *state)
{
  Class klass = lua_objc_toid(state, 1);
  const char *selName = lua_tostring(state, 2);
  const char *types = lua_tostring(state, 3);
  if (!class_addMethod(klass, sel_registerName(selName), (IMP)invokeLuaFunction, types)) {
    lua_pushfstring(state, "cannot add method '%s'", selName);
    lua_error(state); return 0;
  }
  lua_getglobal(state, "__LUNOKHOD_DISPATCH");
  lua_pushstring(state, class_getName(klass));
  lua_gettable(state, -2);
  lua_pushfstring(state, "%s", selName);
  lua_pushvalue(state, 4);
  lua_settable(state, -3);
  return 0;
}

static int lua_objc_loadframework(lua_State *state)
{
  NSString *libraryPath = [@"/" stringByAppendingPathComponent:[NSString pathWithComponents:[NSArray arrayWithObjects:@"Library", @"Frameworks", nil]]];
  //TODO bundleLibraryPath
  NSString *userLibraryPath = [NSHomeDirectory() stringByAppendingPathComponent:libraryPath];
  NSString *systemLibraryPath = [@"/System" stringByAppendingPathComponent:libraryPath];
  NSArray *paths = [NSArray arrayWithObjects:userLibraryPath, libraryPath, systemLibraryPath, nil];

  NSString *name = [NSString stringWithUTF8String:lua_tostring(state, -1)];
  NSString *filename = [name stringByAppendingPathExtension:@"framework"];

  for (NSString *path in paths) {
    if ([[NSBundle bundleWithPath:[path stringByAppendingPathComponent:filename]] load]) {
      return 0; // loaded
    }
  }

  // try plain name, maybe it's already specified as a full path (incl. extension)
  if ([[NSBundle bundleWithPath:name] load]) {
    return 0; // loaded
  }

  // failed to load
  lua_pushfstring(state, "cannot load framework '%s'", name);
  lua_error(state);
  return 0;
}

@implementation Lunokhod

- (id)init
{
  if (![super init])
    return nil;

  if (!registeredClasses) {
    registeredClasses = [[NSMapTable alloc] init];
  }

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

  lua_pushstring(luaState_, "newclass");
  lua_pushcfunction(luaState_, lua_objc_newclass);
  lua_settable(luaState_, -3);

  lua_pushstring(luaState_, "addmethod");
  lua_pushcfunction(luaState_, lua_objc_addmethod);
  lua_settable(luaState_, -3);

  lua_pushstring(luaState_, "loadframework");
  lua_pushcfunction(luaState_, lua_objc_loadframework);
  lua_settable(luaState_, -3);

  lua_pushstring(luaState_, "rect");
  lua_pushcfunction(luaState_, lua_objc_rect);
  lua_settable(luaState_, -3);

  lua_pushstring(luaState_, "size");
  lua_pushcfunction(luaState_, lua_objc_size);
  lua_settable(luaState_, -3);

  lua_setglobal(luaState_, "objc");

  lua_newtable(luaState_);
  lua_setglobal(luaState_, "__LUNOKHOD_DISPATCH");

  lua_gc(luaState_, LUA_GCRESTART, 0); // restart collector
  return self;
}

- (void)dealloc
{
  [registeredClasses release];
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
  if (!lua_isnil(luaState_, -1)) {
    const char *msg = lua_tostring(luaState_, -1);
    lua_Debug info;
    lua_getstack(luaState_, 0, &info);
    lua_getfield(luaState_, LUA_GLOBALSINDEX, "f");
    lua_getinfo(luaState_, ">S", &info);

    NSLog(@"Lunokhod error [%d]: %s \n %s", info.currentline, msg, info.short_src);
  }
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

  @try {
    if (luaL_dofile(luaState_, [filename UTF8String]) != 0) {
      [self logCurrentError];
      result = NO;
    }
  }
  @catch (NSException * e) {
    NSLog(@"Lunokhod Objective-C Exception: %@", [e reason]);
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
  @try {
    if (luaL_dostring(luaState_, [string UTF8String]) == 0) {
      return YES;
    } else {
      [self logCurrentError];
      return NO;
    }
  }
  @catch (NSException * e) {
    NSLog(@"Lunokhod Objective-C Exception: %@", [e reason]);
    return NO;
  }
}

@end
