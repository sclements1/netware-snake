/* Actual AppKit settings-sheet QA. Preferences use only a random test suite.
   Run without arguments for functional assertions. An optional first argument
   requests a preview PNG and requires working AppKit rendering services. */
#import <Cocoa/Cocoa.h>
#import "NWConfigurationController.h"
#include <assert.h>

static NSView *findView(NSView *view, NSString *identifier) {
    if ([view.identifier isEqualToString:identifier]) return view;
    for (NSView *child in view.subviews) {
        NSView *found = findView(child, identifier);
        if (found) return found;
    }
    return nil;
}

static NSPopUpButton *popup(NSView *view, NSString *identifier) {
    NSView *result = findView(view, identifier);
    assert([result isKindOfClass:NSPopUpButton.class]);
    return (NSPopUpButton *)result;
}

static NSButton *button(NSView *view, NSString *identifier) {
    NSView *result = findView(view, identifier);
    assert([result isKindOfClass:NSButton.class]);
    return (NSButton *)result;
}

static void selectItem(NSPopUpButton *control, NSInteger index) {
    [control selectItemAtIndex:index];
    assert([NSApp sendAction:control.action to:control.target from:control]);
}

static NSDictionary *persistentValues(NSUserDefaults *defaults, NSString *domain) {
    return [defaults persistentDomainForName:domain] ?: @{};
}

static void verifyModeControls(NSView *view, BOOL smp) {
    for (NSString *identifier in @[@"resolveGaps", @"screenMode", @"eatDesktop", @"speed", @"size", @"cpuSource"])
        assert(!findView(view, identifier).isHiddenOrHasHiddenAncestor);
    assert(findView(view, @"colorPicker").isHiddenOrHasHiddenAncestor == smp);
    assert(popup(view, @"colorStart").isHiddenOrHasHiddenAncestor != smp);
    assert(popup(view, @"cpuPolicy").isHiddenOrHasHiddenAncestor != smp);
}

static NSColorWell *colorWell(NSView *view) {
    NSView *well = findView(view, @"colorPicker");
    assert([well isKindOfClass:NSColorWell.class]);
    return (NSColorWell *)well;
}

static void setColor(NSView *view, NSColor *color) {
    NSColorWell *well = colorWell(view); well.color = color;
    assert([NSApp sendAction:well.action to:well.target from:well]);
}

static void expectCommonDefaults(NSView *view) {
    assert(popup(view, @"screenMode").indexOfSelectedItem == NWScreenModeFourThirds);
    assert(popup(view, @"speed").indexOfSelectedItem == 1);
    assert(popup(view, @"size").indexOfSelectedItem == 1);
    assert(popup(view, @"cpuSource").indexOfSelectedItem == 0);
    assert(button(view, @"resolveGaps").state == NSControlStateValueOff);
    assert(button(view, @"eatDesktop").state == NSControlStateValueOff);
}

static BOOL renderPreview(NSView *view, NSString *path) {
    // AppKit only caches drawable, attached views. Show our own test window
    // without activating an application or changing any existing windows.
    NSWindow *window = view.window;
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameAqua];
    [window orderFront:nil];
    [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [view layoutSubtreeIfNeeded];
    [view setNeedsDisplay:YES];
    [view displayIfNeeded];
    NSBitmapImageRep *bitmap = [view bitmapImageRepForCachingDisplayInRect:view.bounds];
    assert(bitmap != nil);
    [view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];
    // Sandboxed AppKit can construct all controls while its rendering services
    // return a blank bitmap. Never report that as successful visual QA.
    assert(bitmap.bitsPerSample == 8 && bitmap.bitsPerPixel % 8 == 0);
    NSUInteger stride = (NSUInteger)bitmap.bitsPerPixel / 8;
    NSUInteger varied = 0;
    NSUInteger visible = 0;
    NSUInteger alphaIndex = (bitmap.bitmapFormat & NSBitmapFormatAlphaFirst) ? 0 : stride - 1;
    const unsigned char *pixels = bitmap.bitmapData;
    for (NSInteger y = 0; y < bitmap.pixelsHigh; ++y)
        for (NSInteger x = 0; x < bitmap.pixelsWide; ++x) {
            const unsigned char *pixel = pixels + y * bitmap.bytesPerRow + x * stride;
            if (!bitmap.hasAlpha || pixel[alphaIndex] > 0) {
                ++visible;
                if (memcmp(pixels, pixel, stride) != 0) ++varied;
            }
        }
    if (varied < 1000 || visible < 1000) {
        fprintf(stderr, "Native preview unavailable: AppKit rendering services returned a blank bitmap.\n");
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        [window orderOut:nil];
        return NO;
    }
    // The content view is transparent; its window background is outside the
    // cached view hierarchy. Composite the native background behind the cache.
    NSBitmapImageRep *composite = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:NULL
        pixelsWide:bitmap.pixelsWide pixelsHigh:bitmap.pixelsHigh bitsPerSample:8
        samplesPerPixel:4 hasAlpha:YES isPlanar:NO colorSpaceName:NSDeviceRGBColorSpace
        bytesPerRow:0 bitsPerPixel:32];
    assert(composite != nil);
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext = [NSGraphicsContext graphicsContextWithBitmapImageRep:composite];
    [window.appearance performAsCurrentDrawingAppearance:^{
        [NSColor.windowBackgroundColor setFill];
        NSRect bounds = NSMakeRect(0, 0, bitmap.pixelsWide, bitmap.pixelsHigh);
        NSRectFill(bounds);
        [bitmap drawInRect:bounds];
    }];
    [NSGraphicsContext.currentContext flushGraphics];
    [NSGraphicsContext restoreGraphicsState];
    // Also reject a failed bitmap drawing context, which can leave a cache's
    // alpha mask visible while every RGB channel remains zero.
    NSUInteger colored = 0;
    const unsigned char *compositePixels = composite.bitmapData;
    NSUInteger compositeStride = (NSUInteger)composite.bitsPerPixel / 8;
    NSUInteger compositeAlpha = (composite.bitmapFormat & NSBitmapFormatAlphaFirst) ? 0 : compositeStride - 1;
    for (NSInteger y = 0; y < composite.pixelsHigh; ++y)
        for (NSInteger x = 0; x < composite.pixelsWide; ++x) {
            const unsigned char *pixel = compositePixels + y * composite.bytesPerRow + x * compositeStride;
            for (NSUInteger channel = 0; channel < compositeStride; ++channel)
                if ((!composite.hasAlpha || channel != compositeAlpha) && pixel[channel] > 8) { ++colored; break; }
        }
    if (colored < 1000) {
        fprintf(stderr, "Native preview unavailable: AppKit bitmap drawing context returned no RGB content.\n");
        [[NSFileManager defaultManager] removeItemAtPath:path error:NULL];
        [window orderOut:nil];
        return NO;
    }
    NSData *png = [composite representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
    assert(png.length > 0);
    NSString *directory = path.stringByDeletingLastPathComponent;
    NSError *error = nil;
    assert([[NSFileManager defaultManager] createDirectoryAtPath:directory
        withIntermediateDirectories:YES attributes:nil error:&error]);
    assert([png writeToFile:path options:NSDataWritingAtomic error:&error]);
    [window orderOut:nil];
    return YES;
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        [NSApp setActivationPolicy:NSApplicationActivationPolicyProhibited];
        [NSApp finishLaunching];
        NSString *domain = [@"org.netwaresnake.tests.configuration." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:domain];
        [defaults removePersistentDomainForName:domain]; [defaults setInteger:0 forKey:@"mode"]; [defaults synchronize];
        NSDictionary *before = persistentValues(defaults, domain);
        NWConfigurationController *controller = [[NWConfigurationController alloc] initWithDefaults:defaults];
        NSView *view = controller.panel.contentView; assert(view != nil);
        assert(controller.panel.frame.size.height < 900);
        NSPopUpButton *mode = popup(view, @"mode");
        assert(mode.numberOfItems == 3);
        assert(([mode.itemTitles isEqualToArray:@[@"NetWare 3.12", @"NetWare 4.2", @"Modern"]]));
        assert([mode itemAtIndex:2].enabled);
        assert(mode.indexOfSelectedItem == NWModeNetWare312); verifyModeControls(view, NO); expectCommonDefaults(view);
        assert(popup(view, @"screenMode").numberOfItems == 3);
        assert(popup(view, @"speed").numberOfItems == 3 && popup(view, @"size").numberOfItems == 3);
        assert(popup(view, @"cpuSource").numberOfItems == 2 && popup(view, @"cpuSource").enabled);
        assert(([popup(view, @"cpuPolicy").itemTitles isEqualToArray:@[
            @"Detected number up to 31 (Historically accurate)", @"Detected number up to 32", @"Fixed 32"]]));
        NSPopUpButton *palette = popup(view, @"colorStart"); assert(palette.numberOfItems == 32);
        for (NSInteger cpu = 0; cpu < 32; ++cpu) {
            NSUInteger attr = [NWSettings paletteAttributeForCPU:(NSUInteger)cpu colorStart:0];
            NSString *expected = [NSString stringWithFormat:@"CPU %ld — %@", (long)cpu,
                [NWSettings paletteColorNameForAttribute:attr]];
            assert([[palette itemAtIndex:cpu].title isEqualToString:expected]);
            assert([palette itemAtIndex:cpu].image != nil);
        }
        assert([[palette itemAtIndex:31].title isEqualToString:@"CPU 31 — Bright blue"]);

        // The full 3.12 draft, including custom color, is independent of 4.2.
        selectItem(popup(view, @"screenMode"), NWScreenModeUnifiedDesktop);
        selectItem(popup(view, @"speed"), 2); selectItem(popup(view, @"size"), 0);
        selectItem(popup(view, @"cpuSource"), 1);
        button(view, @"resolveGaps").state = NSControlStateValueOn;
        button(view, @"eatDesktop").state = NSControlStateValueOn;
        setColor(view, [NSColor colorWithSRGBRed:0x12 / 255.0 green:0x34 / 255.0 blue:0x56 / 255.0 alpha:1]);
        selectItem(mode, NWModeNetWare42); verifyModeControls(view, YES); expectCommonDefaults(view);
        assert(!colorWell(view).active && palette.indexOfSelectedItem == 0);
        selectItem(popup(view, @"speed"), 0); selectItem(popup(view, @"size"), 2);
        selectItem(popup(view, @"screenMode"), NWScreenModeWidescreen);
        selectItem(popup(view, @"cpuSource"), 1); selectItem(palette, 31);
        selectItem(popup(view, @"cpuPolicy"), NWCPUFixed32);
        assert(!popup(view, @"cpuSource").enabled && popup(view, @"cpuSource").numberOfItems == 1);
        assert([popup(view, @"cpuSource").titleOfSelectedItem isEqualToString:@"Simulated load"]);
        selectItem(popup(view, @"cpuPolicy"), NWCPUDetected32);
        assert(popup(view, @"cpuSource").enabled && popup(view, @"cpuSource").numberOfItems == 2);
        assert(popup(view, @"cpuSource").indexOfSelectedItem == 1); // remembered demo
        selectItem(popup(view, @"cpuSource"), 0);
        selectItem(popup(view, @"cpuPolicy"), NWCPUFixed32);
        selectItem(popup(view, @"cpuPolicy"), NWCPUDetected31);
        assert(popup(view, @"cpuSource").indexOfSelectedItem == 0); // remembered measured
        selectItem(mode, NWModeNetWare312); verifyModeControls(view, NO);
        assert(popup(view, @"screenMode").indexOfSelectedItem == NWScreenModeUnifiedDesktop);
        assert(popup(view, @"speed").indexOfSelectedItem == 2 && popup(view, @"size").indexOfSelectedItem == 0);
        assert(popup(view, @"cpuSource").indexOfSelectedItem == 1);
        assert(button(view, @"resolveGaps").state == NSControlStateValueOn && button(view, @"eatDesktop").state == NSControlStateValueOn);
        assert([before isEqualToDictionary:persistentValues(defaults, domain)]);

        // Restore edits only the active draft. Cancel leaves the entire suite unchanged.
        [button(view, @"restoreDefaults") performClick:nil]; expectCommonDefaults(view);
        assert([before isEqualToDictionary:persistentValues(defaults, domain)]);
        selectItem(mode, NWModeNetWare42);
        assert(popup(view, @"speed").indexOfSelectedItem == 0 && palette.indexOfSelectedItem == 31);
        [button(view, @"cancel") performClick:nil]; assert([before isEqualToDictionary:persistentValues(defaults, domain)]);
        [controller reloadFromDefaults]; expectCommonDefaults(view); verifyModeControls(view, NO);

        // Save serializes both mode profiles, including a choice hidden by Fixed 32.
        setColor(view, [NSColor colorWithSRGBRed:0x12 / 255.0 green:0x34 / 255.0 blue:0x56 / 255.0 alpha:1]);
        selectItem(popup(view, @"screenMode"), NWScreenModeUnifiedDesktop);
        button(view, @"eatDesktop").state = NSControlStateValueOn;
        selectItem(mode, NWModeNetWare42);
        selectItem(popup(view, @"cpuSource"), 1); selectItem(popup(view, @"cpuPolicy"), NWCPUFixed32);
        selectItem(palette, 17); selectItem(popup(view, @"speed"), 0); selectItem(popup(view, @"size"), 2);
        selectItem(popup(view, @"screenMode"), NWScreenModeWidescreen);
        button(view, @"resolveGaps").state = NSControlStateValueOn;
        selectItem(mode, NWModeNetWare312);
        __block NSUInteger notifications = 0;
        id observer = [NSNotificationCenter.defaultCenter addObserverForName:NWSettingsDidChangeNotification
            object:nil queue:nil usingBlock:^(NSNotification *note) { (void)note; ++notifications; }];
        [button(view, @"save") performClick:nil]; assert(notifications == 1);
        NWSettings *saved = [NWSettings settingsWithDefaults:defaults];
        assert(saved.mode == NWModeNetWare312 && saved.screenMode == NWScreenModeUnifiedDesktop && saved.eatDesktop);
        assert([saved.colorHex isEqualToString:@"#123456"] && saved.speed == 1);
        saved.mode = NWModeNetWare42;
        assert(saved.cpuPolicy == NWCPUFixed32 && saved.colorStart == 17 && saved.demo && saved.resolveGaps);
        assert(saved.screenMode == NWScreenModeWidescreen && saved.speed == 0.5 && saved.size == 2 && !saved.eatDesktop);
        NSDictionary *savedValues = persistentValues(defaults, domain);
        selectItem(mode, NWModeNetWare42); [button(view, @"restoreDefaults") performClick:nil]; expectCommonDefaults(view);
        assert(popup(view, @"cpuPolicy").indexOfSelectedItem == NWCPUDetected31 && palette.indexOfSelectedItem == 0);
        assert(popup(view, @"cpuSource").enabled);
        [button(view, @"cancel") performClick:nil]; assert([savedValues isEqualToDictionary:persistentValues(defaults, domain)]);
        [controller reloadFromDefaults]; selectItem(mode, NWModeNetWare42);
        assert(!popup(view, @"cpuSource").enabled && palette.indexOfSelectedItem == 17);
        selectItem(popup(view, @"cpuPolicy"), NWCPUDetected32);
        assert(popup(view, @"cpuSource").indexOfSelectedItem == 1);
        [button(view, @"save") performClick:nil]; assert(notifications == 2);
        saved = [NWSettings settingsWithDefaults:defaults];
        assert(saved.mode == NWModeNetWare42 && saved.cpuPolicy == NWCPUDetected32 && saved.demo);

        selectItem(mode,NWModeModern);
        assert(popup(view,@"screenMode").indexOfSelectedItem==NWScreenModeUnifiedDesktop);
        assert(!popup(view,@"screenMode").enabled && popup(view,@"size").hidden && popup(view,@"cpuPolicy").hidden);
        selectItem(popup(view,@"speed"),2);
        selectItem(mode,NWModeNetWare312);selectItem(mode,NWModeModern);
        assert(popup(view,@"speed").indexOfSelectedItem==2);
        [button(view,@"restoreDefaults") performClick:nil];
        assert(popup(view,@"speed").indexOfSelectedItem==1);
        [button(view,@"save") performClick:nil];
        assert([NWSettings settingsWithDefaults:defaults].mode==NWModeModern);
        BOOL renderingRequested = argc > 1;
        NSString *path = renderingRequested ? [NSString stringWithUTF8String:argv[1]] : nil;
        BOOL rendered = renderingRequested && renderPreview(view, path);
        [NSNotificationCenter.defaultCenter removeObserver:observer];
        [defaults removePersistentDomainForName:domain]; [defaults synchronize];
        puts("Native configuration: separate mode drafts, 3.12 color, 32 CPU color swatches, CPU policies, forced/restored load source, Restore/Cancel/Save PASS");
        if (rendered) printf("Settings preview: %s\n", path.fileSystemRepresentation);
        else if (renderingRequested) return 2;
    }
    return 0;
}
