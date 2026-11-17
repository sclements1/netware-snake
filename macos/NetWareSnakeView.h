#import <ScreenSaver/ScreenSaver.h>
@interface NetWareSnakeView : ScreenSaverView
/* Injection is used by the preview/test host; the saver uses its module defaults. */
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview defaults:(NSUserDefaults *)defaults;
@end
