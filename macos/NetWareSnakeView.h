#import <ScreenSaver/ScreenSaver.h>
@interface NetWareSnakeView : ScreenSaverView
/* Explicitly show the whole desktop only in thumbnails/windowed previews. */
@property(nonatomic) BOOL unifiedOverview;
/* Injection is used by the preview/test host; the saver uses its module defaults. */
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview defaults:(NSUserDefaults *)defaults;
@end
