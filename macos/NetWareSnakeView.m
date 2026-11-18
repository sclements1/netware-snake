#import "NetWareSnakeView.h"
#import "NWCPUReader.h"
#import "NWConfigurationController.h"
#import "NWSettings.h"
#import "NWUnifiedDesktopSession.h"
#import "NWWallpaperSnapshot.h"
#import "nw4_session.h"
#import "nw_geometry.h"
#import "nw_snake.h"
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <math.h>
#import <os/log.h>
#import <stdarg.h>
#import <stdint.h>

static NSString *const NWModuleID = @"org.netwaresnake.mac.saver";
static NSString *const NWBuildTag = @"0.7.4";
static const int NWBandDemo[9] = {5, 17, 28, 44, 75, 44, 28, 17, 5};
static os_log_t NWLogHandle(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        log = os_log_create("org.netwaresnake.mac.saver", "runtime");
    });
    return log;
}
static void NWLogDiagnostic(BOOL enabled, NSString *format, ...) {
    if (!enabled)
        return;
    va_list args;
    va_start(args, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    os_log_info(NWLogHandle(), "%{public}@", message);
}
static void NWLogFailure(NSString *message) {
    os_log_error(NWLogHandle(), "%{public}@", message);
}

static BOOL NWBitmapPixel(uint8_t glyph, int x, int y) {
    if (glyph == 0xdb)
        return YES;
    if (glyph == 0xb2)
        return (x % 2 == 0 || y % 2 == 0);
    if (glyph == 0xb1)
        return ((x + y) % 2 == 0);
    if (glyph == 0xb0)
        return (x % 2 == 0 && y % 2 == 0);
    return NO;
}
static unsigned NWProcessorCountForSettings(NWSettings *settings) {
    if (settings.cpuPolicy == NWCPUFixed32)
        return 32;
    return nw4_processor_count((unsigned)[[NWCPUReader sharedReader] hostProcessorCount],
                               settings.cpuPolicy == NWCPUDetected32);
}

@interface NetWareSnakeView ()
- (void)applyPreferences;
@end
@implementation NetWareSnakeView {
    nw_snake *_core;
    nw4_session *_smp;
    NWUnifiedDesktopSession *_unified;
    NWSettings *_settings;
    NWWallpaperSnapshot *_wallpaper;
    NSNumber *_wallpaperDisplay;
    CGImageRef _shadeImages[4], _smpImages[16][4];
    uint8_t _lastColor[3];
    uint32_t _initialSeed;
    int _columns, _rows;
    BOOL _running, _diagnostics, _reportedCoreFailure, _reportedSMPFailure;
    double _accumulator;
    CFTimeInterval _lastFrameTime, _startTime, _lastPrefsRead;
    uint64_t _lastUnifiedRevision;
    NSUserDefaults *_defaults;
    NWConfigurationController *_configuration;
    __weak NSWindow *_observedWindow;
    NSString *_lastDisplayMapping;
}
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)preview {
    return [self initWithFrame:frame isPreview:preview defaults:nil];
}
- (instancetype)initWithFrame:(NSRect)frame
                    isPreview:(BOOL)preview
                     defaults:(NSUserDefaults *)defaults {
    self = [super initWithFrame:frame isPreview:preview];
    if (self) {
        _unifiedOverview = preview;
        self.animationTimeInterval = 1.0 / 30.0;
        _initialSeed = arc4random() ^ (uint32_t)(uintptr_t)self;
        _defaults = defaults ?: [ScreenSaverDefaults defaultsForModuleWithName:NWModuleID];
        memset(_lastColor, 255, sizeof _lastColor);
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(settingsChanged:)
                                                     name:NWSettingsDidChangeNotification
                                                   object:nil];
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(screensChanged:)
                   name:NSApplicationDidChangeScreenParametersNotification
                 object:nil];
        _startTime = CACurrentMediaTime();
        [self applyPreferences];
        NWLogDiagnostic(_diagnostics, @"INIT build=%@ preview=%d", NWBuildTag, preview);
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_unified detachParticipant:self];
    nw_snake_destroy(_core);
    nw4_session_destroy(_smp);
    for (int i = 0; i < 4; i++)
        if (_shadeImages[i])
            CGImageRelease(_shadeImages[i]);
    for (int c = 0; c < 16; c++)
        for (int i = 0; i < 4; i++)
            if (_smpImages[c][i])
                CGImageRelease(_smpImages[c][i]);
}
- (BOOL)isFlipped {
    return YES;
}
- (void)setFrameSize:(NSSize)size {
    [super setFrameSize:size];
    if (_defaults)
        [self applyPreferences];
    [self setNeedsDisplay:YES];
}
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (_observedWindow) {
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:NSWindowDidChangeScreenNotification
                                                      object:_observedWindow];
        [[NSNotificationCenter defaultCenter]
            removeObserver:self
                      name:NSWindowDidChangeBackingPropertiesNotification
                    object:_observedWindow];
    }
    _observedWindow = self.window;
    _lastDisplayMapping = nil;
    if (_observedWindow) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(hostScreenChanged:)
                                                     name:NSWindowDidChangeScreenNotification
                                                   object:_observedWindow];
        [[NSNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(hostScreenChanged:)
                   name:NSWindowDidChangeBackingPropertiesNotification
                 object:_observedWindow];
    }
    if (_defaults && self.window)
        [self applyPreferences];
}
- (void)hostScreenChanged:(NSNotification *)note {
    (void)note;
    [self applyPreferences];
    [self setNeedsDisplay:YES];
}
- (void)settingsChanged:(NSNotification *)note {
    (void)note;
    [_defaults synchronize];
    [self applyPreferences];
}
- (void)screensChanged:(NSNotification *)note {
    (void)note;
    _wallpaper = nil;
    _wallpaperDisplay = nil;
    [self applyPreferences];
}
- (void)rebuildGlyphImagesForColor:(const uint8_t *)color {
    if (memcmp(color, _lastColor, 3) == 0 && _shadeImages[0])
        return;
    memcpy(_lastColor, color, 3);
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    const uint8_t patterns[4] = {0xdb, 0xb2, 0xb1, 0xb0};
    for (int i = 0; i < 4; i++) {
        if (_shadeImages[i]) {
            CGImageRelease(_shadeImages[i]);
            _shadeImages[i] = NULL;
        }
        uint8_t pixels[8 * 16 * 4];
        memset(pixels, 0, sizeof pixels);
        for (int y = 0; y < 16; y++)
            for (int x = 0; x < 8; x++) {
                if (NWBitmapPixel(patterns[i], x, y)) {
                    uint8_t *pixel = &pixels[(y * 8 + x) * 4];
                    pixel[0] = color[0];
                    pixel[1] = color[1];
                    pixel[2] = color[2];
                    pixel[3] = 255;
                }
            }
        CGContextRef bitmap =
            CGBitmapContextCreate(pixels, 8, 16, 8, 8 * 4, space,
                                  kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if (bitmap) {
            _shadeImages[i] = CGBitmapContextCreateImage(bitmap);
            CGContextRelease(bitmap);
        }
    }
    CGColorSpaceRelease(space);
}
/* VGA text foreground attributes. Character bytes and write order come from
   the recovered engine; RGB values use the conventional 16-color VGA palette. */
- (void)buildSMPGlyphImages {
    if (_smpImages[0][0])
        return;
    const uint8_t patterns[4] = {0xdb, 0xb2, 0xb1, 0xb0};
    const uint8_t palette[16][3] = {{0, 0, 0},     {0, 0, 170},    {0, 170, 0},    {0, 170, 170},
                                    {170, 0, 0},   {170, 0, 170},  {170, 85, 0},   {170, 170, 170},
                                    {85, 85, 85},  {85, 85, 255},  {85, 255, 85},  {85, 255, 255},
                                    {255, 85, 85}, {255, 85, 255}, {255, 255, 85}, {255, 255, 255}};
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    for (int c = 0; c < 16; c++)
        for (int i = 0; i < 4; i++) {
            uint8_t pixels[8 * 16 * 4] = {0};
            for (int y = 0; y < 16; y++)
                for (int x = 0; x < 8; x++)
                    if (NWBitmapPixel(patterns[i], x, y)) {
                        uint8_t *pixel = &pixels[(y * 8 + x) * 4];
                        memcpy(pixel, palette[c], 3);
                        pixel[3] = 255;
                    }
            CGContextRef bitmap =
                CGBitmapContextCreate(pixels, 8, 16, 8, 32, space,
                                      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
            if (bitmap) {
                _smpImages[c][i] = CGBitmapContextCreateImage(bitmap);
                CGContextRelease(bitmap);
            }
        }
    CGColorSpaceRelease(space);
}

- (void)startSMPSession {
    if (!_smp || nw4_session_columns(_smp) != _columns || nw4_session_rows(_smp) != _rows) {
        nw4_session *fresh = nw4_session_create_grid(_columns, _rows);
        if (fresh) {
            nw4_session_destroy(_smp);
            _smp = fresh;
        } else {
            if (!_reportedSMPFailure)
                NWLogFailure(@"Failed to allocate NetWare 4.2 simulation state");
            _reportedSMPFailure = YES;
            return;
        }
    }
    if (!nw4_session_start_configured(_smp, NWProcessorCountForSettings(_settings),
                                      (unsigned)_settings.colorStart)) {
        if (!_reportedSMPFailure)
            NWLogFailure(@"Failed to allocate NetWare 4.2 simulation state");
        _reportedSMPFailure = YES;
        return;
    }
    _reportedSMPFailure = NO;
    _accumulator = 0;
    _startTime = CACurrentMediaTime();
    [self buildSMPGlyphImages];
    [self setNeedsDisplay:YES];
}
- (void)captureWallpaperIfNeeded {
    if (!_running || !_settings.eatDesktop || _settings.screenMode == NWScreenModeUnifiedDesktop)
        return;
    NSScreen *screen = self.window.screen ?: NSScreen.screens.firstObject;
    NSNumber *display = screen.deviceDescription[@"NSScreenNumber"];
    if (!_wallpaper || ![_wallpaperDisplay isEqual:display]) {
        _wallpaper = screen ? [NWWallpaperSnapshot snapshotForScreen:screen] : nil;
        _wallpaperDisplay = display;
    }
}
- (void)applyPreferences {
    NWSettings *next = [NWSettings settingsWithDefaults:_defaults];
    NWSettings *previous = _settings;
    BOOL first = previous == nil, modeChanged = first || previous.mode != next.mode;
    BOOL eatChanged = first || previous.eatDesktop != next.eatDesktop;
    BOOL screenChanged = first || previous.screenMode != next.screenMode;
    if (eatChanged || modeChanged || screenChanged) {
        _wallpaper = nil;
        _wallpaperDisplay = nil;
    }
    _settings = next;
    _diagnostics = next.diagnostics;
    if (next.screenMode != NWScreenModeUnifiedDesktop || !_running) {
        [_unified detachParticipant:self];
        _unified = nil;
        _lastUnifiedRevision = 0;
    } else {
        NWUnifiedDesktopSession *world = [NWUnifiedDesktopSession acquireForSettings:next
                                                                         participant:self];
        if (_unified != world) {
            [_unified detachParticipant:self];
            _unified = world;
            _lastUnifiedRevision = 0;
        }
        if (!_unified && !_reportedCoreFailure) {
            NWLogFailure(@"Failed to allocate unified desktop simulation");
            _reportedCoreFailure = YES;
        }
    }
    if (next.screenMode != NWScreenModeUnifiedDesktop) {
        int columns = 80, rows = 25;
        if (next.screenMode == NWScreenModeFourThirds) {
            // Multiples of five keep the VGA raster at 8:16 in every size.
            rows = next.size == 0 ? 35 : next.size == 2 ? 20 : 25;
            columns = rows * 16 / 5;
        } else {
            rows = next.size == 0 ? 34 : next.size == 2 ? 18 : 25;
            double ratio = self.bounds.size.height > 0
                               ? self.bounds.size.width / self.bounds.size.height
                               : 1.6;
            columns = MAX(40, MIN(4096, (int)floor(ratio * rows * 2.0)));
        }
        _columns = columns;
        _rows = rows;
        if (next.mode == NWModeNetWare42) {
            if (!_smp || nw4_session_columns(_smp) != columns || nw4_session_rows(_smp) != rows ||
                modeChanged || screenChanged || eatChanged ||
                previous.cpuPolicy != next.cpuPolicy || previous.colorStart != next.colorStart ||
                nw4_session_processors(_smp) != NWProcessorCountForSettings(next))
                [self startSMPSession];
        } else if (!_core || columns != nw_snake_columns(_core) || rows != nw_snake_rows(_core) ||
                   modeChanged || screenChanged || eatChanged) {
            nw_snake *fresh = nw_snake_create(columns, rows, _initialSeed);
            if (fresh) {
                if (columns != 80 || rows != 25)
                    nw_snake_recenter(fresh);
                nw_snake_destroy(_core);
                _core = fresh;
                _columns = columns;
                _rows = rows;
                _accumulator = 0;
                _reportedCoreFailure = NO;
                _startTime = CACurrentMediaTime();
            } else if (!_reportedCoreFailure) {
                NWLogFailure(@"Failed to allocate NetWare 3.12 simulation state");
                _reportedCoreFailure = YES;
            }
        }
    }
    if (!first && (previous.demo != next.demo || previous.speed != next.speed)) {
        _lastFrameTime = _startTime = CACurrentMediaTime();
        _accumulator = 0;
    }
    unsigned rgb = 0xaa0000;
    NSScanner *scanner = [NSScanner scannerWithString:[next.colorHex substringFromIndex:1]];
    [scanner scanHexInt:&rgb];
    const uint8_t color[3] = {(uint8_t)(rgb >> 16), (uint8_t)(rgb >> 8), (uint8_t)rgb};
    [self rebuildGlyphImagesForColor:color];
    if (next.mode != NWModeNetWare312)
        [self buildSMPGlyphImages];
    [self captureWallpaperIfNeeded];
    [self setNeedsDisplay:YES];
}
- (void)startAnimation {
    _running = YES;
    _lastFrameTime = _startTime = CACurrentMediaTime();
    _accumulator = 0;
    _wallpaper = nil;
    _wallpaperDisplay = nil;
    if (_core) {
        nw_snake_reset(_core, _initialSeed);
        if (nw_snake_columns(_core) != 80 || nw_snake_rows(_core) != 25)
            nw_snake_recenter(_core);
    }
    [self applyPreferences];
    if (_settings.mode == NWModeNetWare42 && _settings.screenMode != NWScreenModeUnifiedDesktop &&
        _smp && nw4_session_intervals(_smp) > 0)
        [self startSMPSession];
    NWLogDiagnostic(_diagnostics, @"START build=%@ mode=%ld", NWBuildTag, (long)_settings.mode);
    [super startAnimation];
}
- (void)stopAnimation {
    NWLogDiagnostic(_diagnostics, @"STOP build=%@", NWBuildTag);
    [super stopAnimation];
    _running = NO;
    _lastFrameTime = 0;
    [_unified detachParticipant:self];
    _unified = nil;
    _wallpaper = nil;
    _wallpaperDisplay = nil;
}
- (void)animateOneFrame {
    if (!self.window || [self isHiddenOrHasHiddenAncestor])
        return;
    CFTimeInterval now = CACurrentMediaTime();
    if (now - _lastPrefsRead > 2) {
        _lastPrefsRead = now;
        [_defaults synchronize];
        [self applyPreferences];
    }
    if (_settings.screenMode == NWScreenModeUnifiedDesktop) {
        [_unified advanceAtTime:now];
        if (_lastUnifiedRevision != _unified.revision) {
            _lastUnifiedRevision = _unified.revision;
            [self setNeedsDisplay:YES];
        }
        return;
    }
    if (!_lastFrameTime) {
        _lastFrameTime = now;
        return;
    }
    double dt = fmax(0, fmin(0.25, now - _lastFrameTime));
    _lastFrameTime = now;
    BOOL smp = _settings.mode == NWModeNetWare42;
    _accumulator += dt * _settings.speed * 18.2;
    unsigned loads[32] = {0};
    int cpu = 0;
    if (smp) {
        if (!_smp || nw4_session_processors(_smp) != NWProcessorCountForSettings(_settings))
            [self startSMPSession];
        if (_settings.cpuPolicy == NWCPUFixed32 || _settings.demo) {
            NSUInteger step = (NSUInteger)fmax(0, floor((now - _startTime) / 5.0));
            for (NSUInteger p = 0; p < 32; p++)
                loads[p] = NWBandDemo[(step + p) % 9];
        } else {
            NSArray<NSNumber *> *values = [[NWCPUReader sharedReader] processorUsagesAtTime:now];
            for (NSUInteger p = 0; p < MIN((NSUInteger)32, values.count); p++)
                loads[p] = (unsigned)lround(fmax(0, fmin(100, values[p].doubleValue)));
        }
    } else if (_settings.demo) {
        NSUInteger index = (NSUInteger)fmax(0, floor((now - _startTime) / 5.0)) % 9;
        cpu = NWBandDemo[index];
    } else
        cpu = (int)lround([[NWCPUReader sharedReader] aggregateUsageAtTime:now]);
    BOOL redraw = NO;
    for (int n = 0; _accumulator >= 1 && n < 8; n++) {
        if (smp) {
            if (nw4_session_tick(_smp, loads, 32))
                redraw = YES;
        } else if (_core) {
            unsigned flags = nw_snake_advance(_core, cpu);
            if ((flags & (_settings.resolveGaps ? NW_PROTECTED_CHANGED : NW_FRAME_CHANGED)) ||
                (_settings.eatDesktop && (flags & NW_VISITED_CHANGED)))
                redraw = YES;
        }
        _accumulator -= 1;
    }
    if (_accumulator > 8)
        _accumulator = 0;
    if (redraw)
        [self setNeedsDisplay:YES];
}
- (void)drawVisited:(const uint8_t *)visited
            columns:(int)columns
               rows:(int)rows
          cellWidth:(double)cw
         cellHeight:(double)ch
            originX:(double)ox
            originY:(double)oy
            context:(CGContextRef)ctx {
    if (!visited)
        return;
    // Merge adjacent consumed cells into runs so a mostly eaten desktop stays cheap.
    CGContextBeginPath(ctx);
    for (int y = 0; y < rows; y++)
        for (int x = 0; x < columns;) {
            if (!visited[(size_t)y * columns + x]) {
                x++;
                continue;
            }
            int first = x;
            while (x < columns && visited[(size_t)y * columns + x])
                x++;
            CGContextAddRect(ctx, CGRectMake(ox + first * cw, oy + y * ch, (x - first) * cw, ch));
        }
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    CGContextFillPath(ctx);
}
- (void)drawCharacters:(const uint8_t *)frame
            attributes:(const uint8_t *)attributes
               columns:(int)columns
                  rows:(int)rows
             cellWidth:(double)cw
            cellHeight:(double)ch
               originX:(double)ox
               originY:(double)oy
               context:(CGContextRef)ctx {
    if (!frame)
        return;
    for (int y = 0; y < rows; y++)
        for (int x = 0; x < columns; x++) {
            size_t offset = (size_t)y * columns + x;
            uint8_t glyph = frame[offset];
            int stage = glyph == 0xdb   ? 0
                        : glyph == 0xb2 ? 1
                        : glyph == 0xb1 ? 2
                        : glyph == 0xb0 ? 3
                                        : -1;
            if (stage < 0)
                continue;
            CGImageRef image =
                attributes ? _smpImages[attributes[offset] & 15][stage] : _shadeImages[stage];
            if (image)
                CGContextDrawImage(ctx, CGRectMake(ox + x * cw, oy + y * ch, cw, ch), image);
        }
}
- (void)drawUnifiedInContext:(CGContextRef)ctx {
    if (!_unified)
        return;
    const nw_desktop_layout *layout = _unified.layout;
    NSRect extent =
        NSMakeRect(layout->bounds.x, layout->bounds.y, layout->bounds.width, layout->bounds.height);
    NSRect globalView = [self.window convertRectToScreen:[self convertRect:self.bounds toView:nil]];
    BOOL remoteHost = [NSStringFromClass(self.window.class) containsString:@"NSServiceView"];
    NSScreen *screen =
        remoteHost ? NWScreenForRemoteDesktopView(globalView, self.window.screen, _unified.screens)
                   : NWScreenForDesktopView(globalView, self.window.screen, _unified.screens);
    if (_diagnostics) {
        NSString *mapping = [NSString
            stringWithFormat:
                @"pid=%d window=%@ preview=%d overview=%d hostDisplay=%@ chosenDisplay=%@ "
                 "bounds=%@ windowFrame=%@ globalView=%@ chosenFrame=%@",
                NSProcessInfo.processInfo.processIdentifier, NSStringFromClass(self.window.class),
                self.isPreview, self.unifiedOverview,
                self.window.screen.deviceDescription[@"NSScreenNumber"],
                screen.deviceDescription[@"NSScreenNumber"], NSStringFromRect(self.bounds),
                NSStringFromRect(self.window.frame), NSStringFromRect(globalView),
                NSStringFromRect(screen.frame)];
        NSMutableString *available = [NSMutableString new];
        for (NSScreen *candidate in _unified.screens) {
            [available appendFormat:@" %@:%@", candidate.deviceDescription[@"NSScreenNumber"],
                                    NSStringFromRect(candidate.frame)];
        }
        mapping = [mapping
            stringByAppendingFormat:@" remoteHost=%d availableDisplays=%@", remoteHost, available];
        if (![_lastDisplayMapping isEqual:mapping]) {
            _lastDisplayMapping = mapping;
            // Only log changed mappings after diagnostics have been explicitly enabled.
            NWLogDiagnostic(_diagnostics, @"DISPLAY_MAPPING build=%@ %@", NWBuildTag, mapping);
        }
    } else {
        _lastDisplayMapping = nil;
    }
    CGContextSaveGState(ctx);
    if (!self.unifiedOverview && screen) {
        // Full-screen rendering must never fall back to a complete-desktop
        // overview because host view sizes or backing scales differ.
        NSRect crop = NWDesktopRectForScreen(screen);
        double scale = fmin(self.bounds.size.width / crop.size.width,
                            self.bounds.size.height / crop.size.height);
        CGContextTranslateCTM(
            ctx, self.bounds.origin.x + (self.bounds.size.width - crop.size.width * scale) / 2,
            self.bounds.origin.y + (self.bounds.size.height - crop.size.height * scale) / 2);
        CGContextScaleCTM(ctx, scale, scale);
        CGContextTranslateCTM(ctx, -crop.origin.x, -crop.origin.y);
        CGContextClipToRect(ctx, NSRectToCGRect(crop));
    } else {
        double scale = fmin(self.bounds.size.width / extent.size.width,
                            self.bounds.size.height / extent.size.height);
        CGContextTranslateCTM(
            ctx, (self.bounds.size.width - extent.size.width * scale) / 2 - extent.origin.x * scale,
            (self.bounds.size.height - extent.size.height * scale) / 2 - extent.origin.y * scale);
        CGContextScaleCTM(ctx, scale, scale);
    }
    if (_settings.mode == NWModeModern) {
        if (_settings.eatDesktop)
            for (NSScreen *s in _unified.screens)
                [_unified.wallpapers[s.deviceDescription[@"NSScreenNumber"]]
                    drawInRect:NWDesktopRectForScreen(s)];
        for (NSUInteger p = 0; p < _unified.modern.count; p++) {
            nw4_session *session = [_unified.modern sessionAtIndex:p];
            const nw_desktop_layout *grid = [_unified.modern layoutAtIndex:p];
            if (_settings.eatDesktop)
                [self drawVisited:nw4_session_visited(session)
                          columns:grid->columns
                             rows:grid->rows
                        cellWidth:grid->cell_width
                       cellHeight:grid->cell_height
                          originX:grid->origin_x
                          originY:grid->origin_y
                          context:ctx];
        }
        for (NSUInteger p = 0; p < _unified.modern.count; p++) {
            nw4_session *session = [_unified.modern sessionAtIndex:p];
            const nw_desktop_layout *grid = [_unified.modern layoutAtIndex:p];
            [self drawCharacters:_settings.resolveGaps ? nw4_session_protected_characters(session)
                                                       : nw4_session_characters(session)
                      attributes:_settings.resolveGaps ? nw4_session_protected_attributes(session)
                                                       : nw4_session_attributes(session)
                         columns:grid->columns
                            rows:grid->rows
                       cellWidth:grid->cell_width
                      cellHeight:grid->cell_height
                         originX:grid->origin_x
                         originY:grid->origin_y
                         context:ctx];
        }
        CGContextRestoreGState(ctx);
        return;
    }
    BOOL smp = _settings.mode == NWModeNetWare42;
    if (_settings.eatDesktop) {
        for (NSScreen *s in _unified.screens) {
            NWWallpaperSnapshot *snapshot =
                _unified.wallpapers[s.deviceDescription[@"NSScreenNumber"]];
            [snapshot drawInRect:NWDesktopRectForScreen(s)];
        }
        [self drawVisited:smp ? nw4_session_visited(_unified.smp) : nw_snake_visited(_unified.core)
                  columns:layout->columns
                     rows:layout->rows
                cellWidth:layout->cell_width
               cellHeight:layout->cell_height
                  originX:layout->origin_x
                  originY:layout->origin_y
                  context:ctx];
    }
    const uint8_t *frame =
        smp ? (_settings.resolveGaps ? nw4_session_protected_characters(_unified.smp)
                                     : nw4_session_characters(_unified.smp))
            : nw_snake_frame(_unified.core, _settings.resolveGaps);
    const uint8_t *attributes =
        smp ? (_settings.resolveGaps ? nw4_session_protected_attributes(_unified.smp)
                                     : nw4_session_attributes(_unified.smp))
            : NULL;
    [self drawCharacters:frame
              attributes:attributes
                 columns:layout->columns
                    rows:layout->rows
               cellWidth:layout->cell_width
              cellHeight:layout->cell_height
                 originX:layout->origin_x
                 originY:layout->origin_y
                 context:ctx];
    CGContextRestoreGState(ctx);
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    CGContextRef ctx = NSGraphicsContext.currentContext.CGContext;
    if (!ctx)
        return;
    CGContextSetRGBFillColor(ctx, 0, 0, 0, 1);
    CGContextFillRect(ctx, NSRectToCGRect(self.bounds));
    CGContextSetInterpolationQuality(ctx, kCGInterpolationNone);
    CGContextSetShouldAntialias(ctx, false);
    if (_settings.screenMode == NWScreenModeUnifiedDesktop) {
        [self drawUnifiedInContext:ctx];
        return;
    }
    BOOL smp = _settings.mode == NWModeNetWare42;
    if ((smp && !_smp) || (!smp && !_core))
        return;
    // A failed resize retains the previous engine; always render its actual grid.
    int columns = smp ? nw4_session_columns(_smp) : nw_snake_columns(_core);
    int rows = smp ? nw4_session_rows(_smp) : nw_snake_rows(_core);
    if (_settings.eatDesktop)
        [_wallpaper drawInRect:self.bounds];
    double cw = 0, ch = 0, ox = 0, oy = 0;
    nw_grid_metrics_for_mode(self.bounds.size.width, self.bounds.size.height, columns, rows,
                             _settings.screenMode == NWScreenModeFourThirds, &cw, &ch, &ox, &oy);
    if (cw <= 0 || ch <= 0)
        return;
    if (_settings.eatDesktop)
        [self drawVisited:smp ? nw4_session_visited(_smp) : nw_snake_visited(_core)
                  columns:columns
                     rows:rows
                cellWidth:cw
               cellHeight:ch
                  originX:ox
                  originY:oy
                  context:ctx];
    const uint8_t *frame = smp ? (_settings.resolveGaps ? nw4_session_protected_characters(_smp)
                                                        : nw4_session_characters(_smp))
                               : nw_snake_frame(_core, _settings.resolveGaps);
    const uint8_t *attributes =
        smp ? (_settings.resolveGaps ? nw4_session_protected_attributes(_smp)
                                     : nw4_session_attributes(_smp))
            : NULL;
    [self drawCharacters:frame
              attributes:attributes
                 columns:columns
                    rows:rows
               cellWidth:cw
              cellHeight:ch
                 originX:ox
                 originY:oy
                 context:ctx];
}
- (BOOL)hasConfigureSheet {
    return YES;
}
- (NSWindow *)configureSheet {
    if (!_configuration || !_configuration.panel.sheetParent)
        _configuration = [[NWConfigurationController alloc] initWithDefaults:_defaults];
    return _configuration.panel;
}
@end
