#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

/** Optional explicit tiling override for synthetic images or known settings.
 NSWorkspace's documented desktop options do not expose a tiling key. */
FOUNDATION_EXPORT NSString * const NWWallpaperSnapshotTileOptionKey;

/** A frozen rendering of a display's desktop picture, without screen capture.
 Construct once when animation starts. Dynamic pictures use one available image
 frame; inaccessible or unavailable pictures use the desktop fill color. */
@interface NWWallpaperSnapshot : NSObject
@property(nonatomic, readonly, nullable) NSImage *image;
@property(nonatomic, readonly) NSSize canvasSize;
@property(nonatomic, readonly) NSSize rasterSize;
@property(nonatomic, readonly) NSColor *backgroundColor;

+ (instancetype)snapshotForScreen:(NSScreen *)screen;
+ (NSDictionary<NSNumber *, NWWallpaperSnapshot *> *)snapshotsForScreens:(NSArray<NSScreen *> *)screens;

/** Testable rendering path. Does not read wallpaper settings or any file.
 Options are the public NSWorkspaceDesktopImage... keys, plus the explicit
 NWWallpaperSnapshotTileOptionKey. The raster is capped at 4096 px per axis. */
- (instancetype)initWithImage:(nullable NSImage *)image
                     options:(nullable NSDictionary<NSString *, id> *)options
                  canvasSize:(NSSize)canvasSize NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;

/** Draw upright in a normal or flipped AppKit graphics context. */
- (void)drawInRect:(NSRect)rect;
@end

NS_ASSUME_NONNULL_END
