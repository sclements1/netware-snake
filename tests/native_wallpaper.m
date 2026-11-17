/* Offscreen synthetic pictures only: never queries the user's desktop image. */
#import <AppKit/AppKit.h>
#import "NWWallpaperSnapshot.h"
#include <assert.h>
#include <math.h>

static NSUInteger draws;
static NSImage *picture(NSSize size) {
    return [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect rect) {
        draws++;
        [[NSColor colorWithSRGBRed:1 green:0 blue:0 alpha:1] setFill];
        NSRectFill(NSMakeRect(0, 0, rect.size.width, rect.size.height/2));
        [[NSColor colorWithSRGBRed:0 green:0 blue:1 alpha:1] setFill];
        NSRectFill(NSMakeRect(0, rect.size.height/2, rect.size.width, rect.size.height/2));
        return YES;
    }];
}
static NSBitmapImageRep *render(NWWallpaperSnapshot *snapshot, NSSize size, BOOL flipped) {
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef raster=CGBitmapContextCreate(NULL,size.width,size.height,8,0,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space);
    NSGraphicsContext *base = [NSGraphicsContext graphicsContextWithCGContext:raster flipped:NO];
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = base;
    if (flipped) {
        CGContextTranslateCTM(base.CGContext, 0, size.height);
        CGContextScaleCTM(base.CGContext, 1, -1);
        NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithCGContext:base.CGContext flipped:YES];
    }
    [snapshot drawInRect:NSMakeRect(0, 0, size.width, size.height)];
    [NSGraphicsContext restoreGraphicsState];
    CGImageRef result=CGBitmapContextCreateImage(raster);
    NSBitmapImageRep *bitmap=[[NSBitmapImageRep alloc]initWithCGImage:result];
    CGImageRelease(result);CGContextRelease(raster);
    return bitmap;
}
static void color(NSBitmapImageRep *bitmap, NSInteger x, NSInteger y, CGFloat r, CGFloat g, CGFloat b) {
    // The test renderer explicitly uses sRGB. colorAtX:y: returns a legacy
    // calibrated NSColor on some macOS versions even for an sRGB bitmap.
    NSUInteger components[4];[bitmap getPixel:components atX:x y:y];
    CGFloat red=components[0]/255.0, green=components[1]/255.0, blue=components[2]/255.0;
    if (fabs(red-r)>=0.03 || fabs(green-g)>=0.03 || fabs(blue-b)>=0.03)
        fprintf(stderr,"Pixel %ld,%ld got %.3f %.3f %.3f; expected %.3f %.3f %.3f\n",(long)x,(long)y,red,green,blue,r,g,b);
    assert(fabs(red-r)<0.03);
    assert(fabs(green-g)<0.03);
    assert(fabs(blue-b)<0.03);
    assert(components[3]==255);
}
int main(void) {
    @autoreleasepool {
        NSImage *source = picture(NSMakeSize(4, 2));
        NSDictionary *fit = @{NSWorkspaceDesktopImageFillColorKey:[NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1]};
        NWWallpaperSnapshot *snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:fit canvasSize:NSMakeSize(20, 20)];
        NSUInteger frozenDraws = draws;
        assert(snapshot.image && NSEqualSizes(snapshot.rasterSize, NSMakeSize(20, 20)));
        NSBitmapImageRep *normal = render(snapshot, NSMakeSize(20, 20), NO);
        NSBitmapImageRep *flipped = render(snapshot, NSMakeSize(20, 20), YES);
        assert(draws==frozenDraws); // Activating freezes the source once.
        color(normal, 10, 1, 0, 1, 0); // Letterbox.
        color(normal, 10, 7, 0, 0, 1); // Top half remains blue.
        color(normal, 10, 12, 1, 0, 0);
        color(flipped, 10, 1, 0, 1, 0);
        color(flipped, 10, 7, 0, 0, 1);
        color(flipped, 10, 12, 1, 0, 0);
        NSDictionary *fill = @{NSWorkspaceDesktopImageFillColorKey:[NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1],
            NSWorkspaceDesktopImageAllowClippingKey:@YES};
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:fill canvasSize:NSMakeSize(20, 20)];
        normal = render(snapshot, NSMakeSize(20, 20), NO);
        color(normal, 10, 1, 0, 0, 1); color(normal, 10, 18, 1, 0, 0);
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:@{NSWorkspaceDesktopImageScalingKey:@(NSImageScaleAxesIndependently)} canvasSize:NSMakeSize(20, 20)];
        normal = render(snapshot, NSMakeSize(20, 20), YES);
        color(normal, 10, 1, 0, 0, 1); color(normal, 10, 18, 1, 0, 0);
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:@{NSWorkspaceDesktopImageScalingKey:@(NSImageScaleNone),NSWorkspaceDesktopImageFillColorKey:[NSColor colorWithSRGBRed:0 green:1 blue:0 alpha:1]} canvasSize:NSMakeSize(20, 20)];
        normal = render(snapshot, NSMakeSize(20, 20), NO);
        color(normal, 1, 1, 0, 1, 0); color(normal, 10, 9, 0, 0, 1); color(normal, 10, 10, 1, 0, 0);
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:@{NWWallpaperSnapshotTileOptionKey:@YES} canvasSize:NSMakeSize(20, 20)];
        normal = render(snapshot, NSMakeSize(20, 20), NO);
        for (NSInteger x=1;x<20;x+=4) {
            color(normal, x, 0, 0, 0, 1); color(normal, x, 1, 1, 0, 0);
        }
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:nil options:@{NSWorkspaceDesktopImageFillColorKey:[NSColor colorWithSRGBRed:0.2 green:0.4 blue:0.6 alpha:0.1]} canvasSize:NSMakeSize(20, 20)];
        normal = render(snapshot, NSMakeSize(20, 20), NO);
        color(normal, 1, 1, 0.2, 0.4, 0.6);
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:nil options:nil canvasSize:NSMakeSize(NAN, -2)];
        assert(NSEqualSizes(snapshot.canvasSize, NSMakeSize(1,1)));
        color(render(snapshot, NSMakeSize(1,1), YES), 0, 0, 0, 0, 0);
        snapshot = [[NWWallpaperSnapshot alloc] initWithImage:source options:fit canvasSize:NSMakeSize(10000,5000)];
        assert(NSEqualSizes(snapshot.rasterSize, NSMakeSize(4096,2048)));
        normal = render(snapshot, NSMakeSize(20,10), YES);
        color(normal, 10, 1, 0, 0, 1); color(normal, 10, 8, 1, 0, 0);
        assert([NWWallpaperSnapshot snapshotsForScreens:@[]].count==0);
        puts("Wallpaper snapshot: synthetic fit/fill/stretch/center/tile, flipped drawing, frozen source, fallback and raster cap PASS");
    }
    return 0;
}
