#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import "Lunokhod.h"

int main (int argc, const char * argv[])
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

  NSString *path = [[[[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];


  Lunokhod *lun = [[Lunokhod alloc] init];
  [lun addPackagePath:[path stringByAppendingPathComponent:@"Source/?.lua"]];

  NSString *filename = [path stringByAppendingPathComponent:@"Source/main.lua"];

  [lun doFile:filename];

  //filename = [path stringByAppendingPathComponent:@"Source/blog.lua"];

  //[lun doFile:filename];

//  if ([lun loadFile:filename withFunctionName:@"objc_test"]) {
//    [lun doString:@"objc_test()"];
//  }
  /*
  id a = [[NSClassFromString(@"MySubClass") alloc] init];
  NSLog(@"return: %@", [a secondTest:10 and:20.0 also:@"test"]);
  */
  [lun release];

  [pool drain];
  return 0;
}
