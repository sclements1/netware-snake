#import <Foundation/Foundation.h>
@interface NWCPUReader : NSObject
+ (instancetype)sharedReader;
/* Aggregate host CPU usage, shared across all ScreenSaverView instances in a process.
   Cached for 0.5 seconds; 0% until two valid samples are available. */
- (double)aggregateUsageAtTime:(CFTimeInterval)now;
@end
