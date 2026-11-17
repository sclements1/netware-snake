#import <Cocoa/Cocoa.h>
#import <objc/runtime.h>
#import "NWModernSession.h"
#include <assert.h>
int main(void){@autoreleasepool{
 NSArray *actual=[NWModernSession hostCoreTypes];assert(actual.count>=1&&actual.count<=128);
 printf("Host topology:");for(NSString *type in actual)printf(" %s",type.UTF8String);puts("");
 NSMutableArray *fixture=[NSMutableArray new];for(int p=0;p<128;p++)[fixture addObject:@[@"E",@"P",@"S",@"Unknown"][p%4]];
 Method method=class_getClassMethod(NWModernSession.class,@selector(hostCoreTypes));
 IMP replacement=imp_implementationWithBlock(^NSArray *(id receiver){(void)receiver;return fixture;});
 IMP old=method_setImplementation(method,replacement);
 NWSettings *settings=[NWSettings new];settings.mode=NWModeModern;
 assert(settings.screenMode==NWScreenModeUnifiedDesktop&&!settings.demo&&settings.speed==1);
 NWModernSession *world=[[NWModernSession alloc] initWithSettings:settings rectangles:@[[NSValue valueWithRect:NSMakeRect(-1280,0,1280,800)],[NSValue valueWithRect:NSMakeRect(0,0,1280,800)]] referenceHeight:800];
 assert(world&&world.count==128);
 assert([world layoutAtIndex:0]->rows==34&&[world layoutAtIndex:1]->rows==25&&[world layoutAtIndex:2]->rows==18&&[world layoutAtIndex:3]->rows==25);
 NSMutableArray *loads=[NSMutableArray new];for(int p=0;p<128;p++)[loads addObject:@(p%101)];
 for(int t=0;t<520;t++)[world advanceWithLoads:loads demo:NO phase:0];
 for(int p=0;p<128;p++)assert(nw4_session_intervals([world sessionAtIndex:p])==(uint64_t)(520-4*p));
 method_setImplementation(method,old);imp_removeBlock(replacement);
 puts("Modern: 128 CPUs, E/P/S/unknown adaptive grids, per-CPU loads and staggered activation PASS");
}return 0;}
