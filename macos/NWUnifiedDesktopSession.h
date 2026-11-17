#import <Cocoa/Cocoa.h>
#import "NWSettings.h"
#import "NWWallpaperSnapshot.h"
#import "nw_snake.h"
#import "NWModernSession.h"
#import "nw4_session.h"
#import "nw_desktop.h"

/* One world and one simulation clock shared by the host's display views.
   Coordinates use global desktop points with y increasing downward. */
@interface NWUnifiedDesktopSession : NSObject
/* Exactly one engine is non-NULL, selected by the active historical mode. */
@property(nonatomic,readonly) nw_snake *core;
@property(nonatomic,readonly) NWModernSession *modern;
@property(nonatomic,readonly) nw4_session *smp;
@property(nonatomic,readonly) const nw_desktop_layout *layout;
@property(nonatomic,readonly) NSArray<NSScreen *> *screens;
@property(nonatomic,readonly) NSDictionary<NSNumber *,NWWallpaperSnapshot *> *wallpapers;
@property(nonatomic,readonly) uint64_t revision;
+ (instancetype)acquireForSettings:(NWSettings *)settings participant:(id)participant;
- (void)detachParticipant:(id)participant;
- (void)advanceAtTime:(CFTimeInterval)time;
@end
FOUNDATION_EXPORT NSRect NWDesktopRectForScreen(NSScreen *screen);
