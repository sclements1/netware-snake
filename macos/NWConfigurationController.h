#import <Cocoa/Cocoa.h>
#import "NWSettings.h"

NS_ASSUME_NONNULL_BEGIN

@interface NWConfigurationController : NSObject <NSWindowDelegate>
@property(nonatomic, readonly) NSPanel *panel;
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
/* Start each presentation from saved preferences, discarding a cancelled draft. */
- (void)reloadFromDefaults;
@end

NS_ASSUME_NONNULL_END
