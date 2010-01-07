#import <Foundation/Foundation.h>
#import "Lunokhod.h"

int main (int argc, const char * argv[]) 
{
  NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];

  Lunokhod *lun = [[Lunokhod alloc] init];
  
  NSString *path = [[[[NSString stringWithUTF8String:argv[0]] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent] stringByDeletingLastPathComponent];
  
  NSString *filename = [path stringByAppendingPathComponent:@"Source/test.lua"];
  
  if ([lun loadFile:filename withFunctionName:@"objc_test"]) {
    [lun doString:@"objc_test()"];    
  }
  
  id a = [[NSClassFromString(@"MySubClass") alloc] init];
  NSLog(@"return: %@", [a secondTest:10 and:20.0 also:@"test"]);

  [lun release];

  [pool drain];
  return 0;
}
