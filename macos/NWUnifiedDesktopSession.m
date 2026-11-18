#import "NWUnifiedDesktopSession.h"
#import "NWCPUReader.h"
#import <QuartzCore/QuartzCore.h>
#import <math.h>

static NWUnifiedDesktopSession *NWActiveDesktop;
static const int NWDemoLevels[9] = {5, 17, 28, 44, 75, 44, 28, 17, 5};
static unsigned NWUnifiedProcessorCount(NWSettings *settings) {
    if (settings.mode == NWModeModern)
        return (unsigned)MIN((NSUInteger)128,
                             MAX((NSUInteger)1, NSProcessInfo.processInfo.processorCount));
    if (settings.mode != NWModeNetWare42)
        return 0;
    if (settings.cpuPolicy == NWCPUFixed32)
        return 32;
    NSUInteger cap = settings.cpuPolicy == NWCPUDetected32 ? 32 : 31;
    return (unsigned)MIN(cap, MAX((NSUInteger)1, [[NWCPUReader sharedReader] hostProcessorCount]));
}
static unsigned NWUnifiedPercentage(double percentage) {
    return isfinite(percentage) ? (unsigned)lround(fmax(0, fmin(100, percentage))) : 0;
}
NSRect NWDesktopRectForScreen(NSScreen *screen) {
    NSRect r = screen.frame;
    return NSMakeRect(r.origin.x, -NSMaxY(r), r.size.width, r.size.height);
}
NSScreen *NWScreenForDesktopView(NSRect globalView, NSScreen *hint, NSArray<NSScreen *> *screens) {
    // Remote screen saver windows can retain the main display's frame while
    // their screen property already identifies the correct physical display.
    // Never override that display identity with inferred window coordinates.
    NSNumber *displayID = hint.deviceDescription[@"NSScreenNumber"];
    if (displayID)
        for (NSScreen *screen in screens)
            if ([screen.deviceDescription[@"NSScreenNumber"] isEqual:displayID])
                return screen;
    NSScreen *best = [screens containsObject:hint] ? hint : screens.firstObject;
    NSRect intersection = best ? NSIntersectionRect(globalView, best.frame) : NSZeroRect;
    double area = intersection.size.width * intersection.size.height;
    for (NSScreen *screen in screens) {
        NSRect r = NSIntersectionRect(globalView, screen.frame);
        double candidate = r.size.width * r.size.height;
        if (candidate > area) {
            area = candidate;
            best = screen;
        }
    }
    return best;
}
static NSScreen *NWExactDisplay(NSRect rect, NSArray<NSScreen *> *screens) {
    for (NSScreen *screen in screens) {
        NSRect f = screen.frame;
        if (fabs(rect.origin.x - f.origin.x) < 2 && fabs(rect.origin.y - f.origin.y) < 2 &&
            fabs(rect.size.width - f.size.width) < 2 && fabs(rect.size.height - f.size.height) < 2)
            return screen;
    }
    return nil;
}
NSScreen *NWScreenForRemoteDesktopView(NSRect globalView, NSScreen *hint,
                                       NSArray<NSScreen *> *screens) {
    // NSServiceViewControllerWindow may expose a top-left-origin remote frame
    // even though NSScreen frames use Cocoa's bottom-left desktop coordinates.
    // Only a unique exact geometry match may override the host's identity.
    NSScreen *primary = screens.firstObject;
    NSRect flipped = NSMakeRect(globalView.origin.x, NSMaxY(primary.frame) - NSMaxY(globalView),
                                globalView.size.width, globalView.size.height);
    NSScreen *native = NWExactDisplay(globalView, screens),
             *remote = NWExactDisplay(flipped, screens);
    if (native && !remote)
        return native;
    if (remote && !native)
        return remote;
    if (native == remote && native)
        return native;
    return NWScreenForDesktopView(globalView, hint, screens);
}
@implementation NWUnifiedDesktopSession {
    nw_snake *_core;
    NWModernSession *_modern;
    nw4_session *_smp;
    nw_desktop_layout _layout;
    NWSettings *_settings;
    NSArray<NSScreen *> *_screens;
    NSDictionary<NSNumber *, NWWallpaperSnapshot *> *_wallpapers;
    NSHashTable *_participants;
    NSString *_signature;
    CFTimeInterval _lastTime, _startTime;
    double _accumulator;
    uint64_t _revision;
}
+ (NSString *)signatureForSettings:(NWSettings *)s
                           screens:(NSArray<NSScreen *> *)screens
                        processors:(unsigned)processors {
    // Presentation and load-source changes retain the simulation and consumed
    // pixels. Only changes that require rebuilding the world form this key.
    BOOL smp = s.mode != NWModeNetWare312;
    NSMutableString *key = [NSMutableString
        stringWithFormat:@"%ld|%ld|%d|%ld|%u|%ld", (long)s.mode, (long)s.size, s.eatDesktop,
                         smp ? (long)s.cpuPolicy : 0L, processors, smp ? (long)s.colorStart : 0L];
    for (NSScreen *screen in screens)
        [key appendFormat:@"|%@:%@", screen.deviceDescription[@"NSScreenNumber"],
                          NSStringFromRect(screen.frame)];
    return key;
}
+ (instancetype)acquireForSettings:(NWSettings *)settings participant:(id)participant {
    NSArray<NSScreen *> *screens = NSScreen.screens;
    if (!screens.count)
        return nil;
    unsigned processors = NWUnifiedProcessorCount(settings);
    NSString *key = [self signatureForSettings:settings screens:screens processors:processors];
    if (!NWActiveDesktop || ![NWActiveDesktop->_signature isEqualToString:key]) {
        NWUnifiedDesktopSession *fresh = [[self alloc] initWithSettings:settings
                                                                screens:screens
                                                              signature:key
                                                             processors:processors];
        if (!fresh)
            return nil;
        NWActiveDesktop = fresh;
    }
    NWUnifiedDesktopSession *world = NWActiveDesktop;
    if (world->_settings.resolveGaps != settings.resolveGaps ||
        (settings.mode == NWModeNetWare312 &&
         ![world->_settings.colorHex isEqual:settings.colorHex]))
        world->_revision++;
    if (world->_settings.demo != settings.demo)
        world->_startTime = CACurrentMediaTime();
    if (world->_settings.speed != settings.speed) {
        world->_accumulator = 0;
        world->_lastTime = CACurrentMediaTime();
    }
    world->_settings = [settings copy];
    [world->_participants addObject:participant];
    return NWActiveDesktop;
}
- (instancetype)initWithSettings:(NWSettings *)settings
                         screens:(NSArray<NSScreen *> *)screens
                       signature:(NSString *)signature
                      processors:(unsigned)processors {
    self = [super init];
    if (!self)
        return nil;
    _settings = [settings copy];
    _screens = [screens copy];
    _signature = [signature copy];
    _participants = [NSHashTable weakObjectsHashTable];
    nw_desktop_rect *rects = calloc(screens.count, sizeof(*rects));
    if (!rects)
        return nil;
    for (NSUInteger i = 0; i < screens.count; i++) {
        NSRect r = NWDesktopRectForScreen(screens[i]);
        rects[i] = (nw_desktop_rect){r.origin.x, r.origin.y, r.size.width, r.size.height};
    }
    BOOL ok = nw_desktop_build(rects, screens.count, screens.firstObject.frame.size.height,
                               (int)settings.size, &_layout);
    free(rects);
    if (!ok)
        return nil;
    size_t cells = (size_t)_layout.columns * _layout.rows;
    if (settings.mode == NWModeModern) {
        NSMutableArray *rectangles = [NSMutableArray new];
        for (NSScreen *s in screens)
            [rectangles addObject:[NSValue valueWithRect:NWDesktopRectForScreen(s)]];
        _modern = [[NWModernSession alloc] initWithSettings:settings
                                                 rectangles:rectangles
                                            referenceHeight:screens.firstObject.frame.size.height];
        if (!_modern)
            return nil;
    } else if (settings.mode == NWModeNetWare42) {
        _smp = nw4_session_create_grid(_layout.columns, _layout.rows);
        if (!_smp || !nw4_session_set_domain(_smp, _layout.domain, cells) ||
            !nw4_session_start_configured(_smp, processors, (unsigned)settings.colorStart))
            return nil;
    } else {
        _core = nw_snake_create(_layout.columns, _layout.rows, arc4random());
        if (!_core || !nw_snake_set_domain(_core, _layout.domain, cells))
            return nil;
    }
    _wallpapers = settings.eatDesktop ? [NWWallpaperSnapshot snapshotsForScreens:screens] : @{};
    _lastTime = _startTime = CACurrentMediaTime();
    _revision = 1;
    return self;
}
- (void)dealloc {
    nw_snake_destroy(_core);
    nw4_session_destroy(_smp);
    nw_desktop_dispose(&_layout);
}
- (nw_snake *)core {
    return _core;
}
- (NWModernSession *)modern {
    return _modern;
}
- (nw4_session *)smp {
    return _smp;
}
- (const nw_desktop_layout *)layout {
    return &_layout;
}
- (NSArray<NSScreen *> *)screens {
    return _screens;
}
- (NSDictionary<NSNumber *, NWWallpaperSnapshot *> *)wallpapers {
    return _wallpapers;
}
- (uint64_t)revision {
    return _revision;
}
- (void)detachParticipant:(id)participant {
    [_participants removeObject:participant];
    if (!_participants.count && NWActiveDesktop == self)
        NWActiveDesktop = nil;
}
- (void)advanceAtTime:(CFTimeInterval)now {
    if (!isfinite(now) || now <= _lastTime)
        return;
    double dt = now - _lastTime;
    _lastTime = now;
    dt = fmin(dt, 0.25);
    double speed = _settings.speed;
    if (!isfinite(speed) || speed <= 0)
        speed = 1;
    _accumulator += dt * speed * 18.2;
    NSUInteger phase = (NSUInteger)fmax(0, floor((now - _startTime) / 5.0)) % 9;
    unsigned loads[32] = {0};
    NSArray *modernLoads =
        _modern && !_settings.demo ? [[NWCPUReader sharedReader] processorUsagesAtTime:now] : @[];
    int cpu = 0;
    if (_smp) {
        BOOL simulated = _settings.demo || _settings.cpuPolicy == NWCPUFixed32;
        if (simulated) {
            for (unsigned p = 0; p < nw4_session_processors(_smp); p++)
                loads[p] = (unsigned)NWDemoLevels[(phase + p) % 9];
        } else {
            NSArray<NSNumber *> *values = [[NWCPUReader sharedReader] processorUsagesAtTime:now];
            for (NSUInteger p = 0; p < MIN((NSUInteger)32, values.count); p++)
                loads[p] = NWUnifiedPercentage(values[p].doubleValue);
        }
    } else
        cpu = _settings.demo
                  ? NWDemoLevels[phase]
                  : (int)NWUnifiedPercentage([[NWCPUReader sharedReader] aggregateUsageAtTime:now]);
    for (int n = 0; _accumulator >= 1 && n < 8; n++) {
        if (_modern) {
            [_modern advanceWithLoads:modernLoads demo:_settings.demo phase:phase];
            _revision++;
        } else if (_smp) {
            if (nw4_session_tick(_smp, loads, 32))
                _revision++;
        } else {
            unsigned flags = nw_snake_advance(_core, cpu);
            if ((flags & (_settings.resolveGaps ? NW_PROTECTED_CHANGED : NW_FRAME_CHANGED)) ||
                (_settings.eatDesktop && (flags & NW_VISITED_CHANGED)))
                _revision++;
        }
        _accumulator -= 1;
    }
    if (_accumulator > 8)
        _accumulator = 0;
}
@end
