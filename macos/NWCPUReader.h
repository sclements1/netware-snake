#import <Foundation/Foundation.h>
@interface NWCPUReader : NSObject
+ (instancetype)sharedReader;
/* Aggregate host CPU usage, shared across all ScreenSaverView instances in a process.
   Cached for 0.5 seconds; 0% until two valid samples are available. */
- (double)aggregateUsageAtTime:(CFTimeInterval)now;
/* Logical CPUs in Mach enumeration order. Shared 0.5s cache, independent
   baseline per CPU; buffers returned by Mach are released after every read. */
- (NSArray<NSNumber *> *)processorUsagesAtTime:(CFTimeInterval)now;
- (NSUInteger)hostProcessorCount;
@end
