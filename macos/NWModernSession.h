#import <Cocoa/Cocoa.h>
#import "NWSettings.h"
#import "nw4_session.h"
#import "nw_desktop.h"
@interface NWModernSession : NSObject
@property(readonly) NSUInteger count;
@property(readonly) NSArray<NSString *> *types;
+ (NSArray<NSString *> *)hostCoreTypes;
- (instancetype)initWithSettings:(NWSettings *)settings rectangles:(NSArray<NSValue *> *)rectangles referenceHeight:(double)height;
- (nw4_session *)sessionAtIndex:(NSUInteger)index;
- (const nw_desktop_layout *)layoutAtIndex:(NSUInteger)index;
- (void)advanceWithLoads:(NSArray<NSNumber *> *)loads demo:(BOOL)demo phase:(NSUInteger)phase;
@end
