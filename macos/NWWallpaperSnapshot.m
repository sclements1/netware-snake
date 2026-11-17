#import "NWWallpaperSnapshot.h"
#import <ImageIO/ImageIO.h>
#include <math.h>

NSString * const NWWallpaperSnapshotTileOptionKey = @"NWWallpaperSnapshotTile";
static const CGFloat NWWallpaperMaximumRasterDimension = 4096;

@interface NWWallpaperSnapshot ()
@property(nonatomic, readwrite, nullable) NSImage *image;
@property(nonatomic, readwrite) NSSize canvasSize;
@property(nonatomic, readwrite) NSSize rasterSize;
@property(nonatomic, readwrite) NSColor *backgroundColor;
@end

static BOOL NWUsableSize(NSSize size) {
    return isfinite(size.width) && isfinite(size.height) && size.width > 0 && size.height > 0;
}

static NSColor *NWDesktopFillColor(NSDictionary<NSString *, id> *options) {
    id value = options[NSWorkspaceDesktopImageFillColorKey];
    NSColor *color = [value isKindOfClass:NSColor.class] ? value : NSColor.blackColor;
    color = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace] ?: NSColor.blackColor;
    return [color colorWithAlphaComponent:1];
}

/* Read exactly one image frame, respecting EXIF orientation. Thumbnail decoding
 bounds memory use for large wallpaper files. The NSImage retains the original
 logical size, so center/tile placement is independent of the decode cap. */
static NSImage * _Nullable NWDesktopPictureAtURL(NSURL * _Nullable url) {
    if (!url.isFileURL) return nil;
    CGImageSourceRef source = CGImageSourceCreateWithURL((__bridge CFURLRef)url, NULL);
    if (!source) return nil;
    NSDictionary *properties = CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(source, 0, NULL));
    NSDictionary *decode = @{
        (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
        (__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
        (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(NWWallpaperMaximumRasterDimension),
        (__bridge NSString *)kCGImageSourceShouldCacheImmediately: @YES
    };
    CGImageRef frame = CGImageSourceCreateThumbnailAtIndex(source, 0, (__bridge CFDictionaryRef)decode);
    CFRelease(source);
    if (!frame) return nil;
    CGFloat width = [properties[(__bridge NSString *)kCGImagePropertyPixelWidth] doubleValue];
    CGFloat height = [properties[(__bridge NSString *)kCGImagePropertyPixelHeight] doubleValue];
    CGFloat dpiX = [properties[(__bridge NSString *)kCGImagePropertyDPIWidth] doubleValue];
    CGFloat dpiY = [properties[(__bridge NSString *)kCGImagePropertyDPIHeight] doubleValue];
    width *= dpiX > 0 && isfinite(dpiX) ? 72 / dpiX : 1;
    height *= dpiY > 0 && isfinite(dpiY) ? 72 / dpiY : 1;
    NSInteger orientation = [properties[(__bridge NSString *)kCGImagePropertyOrientation] integerValue];
    if (orientation >= 5 && orientation <= 8) {
        CGFloat swap = width; width = height; height = swap;
    }
    NSSize size = NSMakeSize(width, height);
    if (!NWUsableSize(size)) size = NSMakeSize(CGImageGetWidth(frame), CGImageGetHeight(frame));
    NSImage *image = [[NSImage alloc] initWithCGImage:frame size:size];
    CFRelease(frame);
    return image;
}

@implementation NWWallpaperSnapshot
+ (instancetype)snapshotForScreen:(NSScreen *)screen {
    NSWorkspace *workspace = NSWorkspace.sharedWorkspace;
    NSDictionary *options = [workspace desktopImageOptionsForScreen:screen] ?: @{};
    NSImage *picture = NWDesktopPictureAtURL([workspace desktopImageURLForScreen:screen]);
    return [[self alloc] initWithImage:picture options:options canvasSize:screen.frame.size];
}

+ (NSDictionary<NSNumber *, NWWallpaperSnapshot *> *)snapshotsForScreens:(NSArray<NSScreen *> *)screens {
    NSMutableDictionary<NSNumber *, NWWallpaperSnapshot *> *snapshots = [NSMutableDictionary dictionary];
    for (NSScreen *screen in screens) {
        id displayID = screen.deviceDescription[@"NSScreenNumber"];
        if ([displayID isKindOfClass:NSNumber.class]) {
            snapshots[displayID] = [self snapshotForScreen:screen];
        }
    }
    return [snapshots copy];
}

- (instancetype)initWithImage:(NSImage *)source options:(NSDictionary<NSString *,id> *)options canvasSize:(NSSize)canvasSize {
    self = [super init];
    if (!self) return nil;
    options = options ?: @{};
    _canvasSize = NWUsableSize(canvasSize) ? canvasSize : NSMakeSize(1, 1);
    _backgroundColor = NWDesktopFillColor(options);
    CGFloat ratio = MIN(1, NWWallpaperMaximumRasterDimension / MAX(_canvasSize.width, _canvasSize.height));
    NSInteger width = MAX(1, (NSInteger)llround(_canvasSize.width * ratio));
    NSInteger height = MAX(1, (NSInteger)llround(_canvasSize.height * ratio));
    _rasterSize = NSMakeSize(width, height);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef raster = CGBitmapContextCreate(NULL, width, height, 8, 0, colorSpace,
        kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!raster) return self; // drawInRect retains an opaque solid fallback.
    NSGraphicsContext *context = [NSGraphicsContext graphicsContextWithCGContext:raster flipped:NO];
    if (!context) { CGContextRelease(raster); return self; }
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = context;
    context.imageInterpolation = NSImageInterpolationHigh;
    NSAffineTransform *scale = [NSAffineTransform transform];
    [scale scaleXBy:(CGFloat)width / _canvasSize.width yBy:(CGFloat)height / _canvasSize.height];
    [scale concat];
    NSRect canvas = NSMakeRect(0, 0, _canvasSize.width, _canvasSize.height);
    [_backgroundColor setFill];
    NSRectFillUsingOperation(canvas, NSCompositingOperationCopy);
    if (source && NWUsableSize(source.size)) {
        BOOL tile = [options[NWWallpaperSnapshotTileOptionKey] boolValue];
        if (tile) {
            // A pattern fill keeps tile rendering bounded even for tiny images.
            NSColor *pattern = [NSColor colorWithPatternImage:source];
            [pattern setFill];
            NSRectFillUsingOperation(canvas, NSCompositingOperationSourceOver);
        } else {
            id setting = options[NSWorkspaceDesktopImageScalingKey];
            NSImageScaling scaling = [setting respondsToSelector:@selector(unsignedIntegerValue)]
                ? [setting unsignedIntegerValue] : NSImageScaleProportionallyUpOrDown;
            CGFloat x = _canvasSize.width / source.size.width;
            CGFloat y = _canvasSize.height / source.size.height;
            NSSize destination = source.size;
            if (scaling == NSImageScaleAxesIndependently) destination = _canvasSize;
            else if (scaling != NSImageScaleNone) {
                BOOL clip = [options[NSWorkspaceDesktopImageAllowClippingKey] boolValue];
                CGFloat factor = clip ? MAX(x, y) : MIN(x, y);
                if (scaling == NSImageScaleProportionallyDown) factor = MIN(1, factor);
                destination = NSMakeSize(source.size.width * factor, source.size.height * factor);
            }
            NSRect target = NSMakeRect((_canvasSize.width-destination.width)/2,
                (_canvasSize.height-destination.height)/2, destination.width, destination.height);
            [NSBezierPath clipRect:canvas];
            [source drawInRect:target fromRect:NSZeroRect operation:NSCompositingOperationSourceOver
                     fraction:1 respectFlipped:YES hints:nil];
        }
    }
    [NSGraphicsContext restoreGraphicsState];
    CGImageRef frame = CGBitmapContextCreateImage(raster);
    if (frame) {
        _image = [[NSImage alloc] initWithCGImage:frame size:_canvasSize];
        CGImageRelease(frame);
    }
    CGContextRelease(raster);
    return self;
}

- (void)drawInRect:(NSRect)rect {
    if (!NWUsableSize(rect.size) || !isfinite(rect.origin.x) || !isfinite(rect.origin.y)) return;
    if (_image) {
        [_image drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationCopy
                 fraction:1 respectFlipped:YES hints:nil];
    } else {
        [_backgroundColor setFill];
        NSRectFillUsingOperation(rect, NSCompositingOperationCopy);
    }
}
@end
