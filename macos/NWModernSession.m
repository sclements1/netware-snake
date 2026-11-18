#import "NWModernSession.h"
#import <IOKit/IOKitLib.h>
@implementation NWModernSession {
    nw4_session *_sessions[128];
    nw_desktop_layout _layouts[128];
    NSUInteger _count;
    NSArray<NSString *> *_types;
    uint64_t _interval;
}
+ (NSArray<NSString *> *)hostCoreTypes {
    NSUInteger count =
        MIN((NSUInteger)128, MAX((NSUInteger)1, NSProcessInfo.processInfo.processorCount));
    NSMutableArray *types = [NSMutableArray new];
    for (NSUInteger p = 0; p < count; p++)
        [types addObject:@"Unknown"];
    io_registry_entry_t cpus = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/cpus");
    io_iterator_t iterator = 0;
    if (cpus &&
        IORegistryEntryGetChildIterator(cpus, kIODeviceTreePlane, &iterator) == KERN_SUCCESS) {
        io_registry_entry_t cpu;
        while ((cpu = IOIteratorNext(iterator))) {
            NSDictionary *properties = nil;
            CFMutableDictionaryRef raw = NULL;
            if (IORegistryEntryCreateCFProperties(cpu, &raw, kCFAllocatorDefault, 0) ==
                KERN_SUCCESS)
                properties = CFBridgingRelease(raw);
            NSNumber *index = properties[@"logical-cpu-id"];
            id value = properties[@"cluster-type"];
            NSString *type = [value isKindOfClass:NSData.class]
                                 ? [[NSString alloc] initWithData:value
                                                         encoding:NSUTF8StringEncoding]
                                 : value;
            type = [type stringByTrimmingCharactersInSet:NSCharacterSet.controlCharacterSet];
            if ([index isKindOfClass:NSNumber.class] && index.unsignedIntegerValue < count &&
                [@[ @"E", @"P", @"S" ] containsObject:type])
                types[index.unsignedIntegerValue] = type;
            IOObjectRelease(cpu);
        }
        IOObjectRelease(iterator);
    }
    if (cpus)
        IOObjectRelease(cpus);
    return types;
}
- (instancetype)initWithSettings:(NWSettings *)settings
                      rectangles:(NSArray<NSValue *> *)rectangles
                 referenceHeight:(double)height {
    self = [super init];
    if (!self)
        return nil;
    _types = [NWModernSession hostCoreTypes];
    _count = _types.count;
    nw_desktop_rect *rects = calloc(rectangles.count, sizeof(*rects));
    if (!rects)
        return nil;
    for (NSUInteger r = 0; r < rectangles.count; r++) {
        NSRect x = rectangles[r].rectValue;
        rects[r] = (nw_desktop_rect){x.origin.x, x.origin.y, x.size.width, x.size.height};
    }
    BOOL ok = YES;
    for (NSUInteger p = 0; p < _count; p++) {
        int size = [_types[p] isEqual:@"E"] ? 0 : [_types[p] isEqual:@"S"] ? 2 : 1;
        if (!nw_desktop_build(rects, rectangles.count, height, size, &_layouts[p])) {
            ok = NO;
            break;
        }
        _sessions[p] = nw4_session_create_grid(_layouts[p].columns, _layouts[p].rows);
        if (!_sessions[p] ||
            !nw4_session_set_domain(_sessions[p], _layouts[p].domain,
                                    (size_t)_layouts[p].columns * _layouts[p].rows) ||
            !nw4_session_start_configured(_sessions[p], 1,
                                          (unsigned)((settings.colorStart + p) % 15))) {
            ok = NO;
            break;
        }
    }
    free(rects);
    return ok ? self : nil;
}
- (void)dealloc {
    for (NSUInteger p = 0; p < 128; p++) {
        nw4_session_destroy(_sessions[p]);
        nw_desktop_dispose(&_layouts[p]);
    }
}
- (NSUInteger)count {
    return _count;
}
- (NSArray<NSString *> *)types {
    return _types;
}
- (nw4_session *)sessionAtIndex:(NSUInteger)index {
    return index < _count ? _sessions[index] : NULL;
}
- (const nw_desktop_layout *)layoutAtIndex:(NSUInteger)index {
    return index < _count ? &_layouts[index] : NULL;
}
- (void)advanceWithLoads:(NSArray<NSNumber *> *)loads demo:(BOOL)demo phase:(NSUInteger)phase {
    const unsigned bands[] = {5, 17, 28, 44, 75, 44, 28, 17, 5};
    for (NSUInteger p = 0; p < _count; p++)
        if (_interval >= 4 * p) {
            unsigned load =
                demo ? bands[(phase + p) % 9]
                     : (p < loads.count ? (unsigned)MAX(0, MIN(100, loads[p].doubleValue)) : 0);
            nw4_session_tick(_sessions[p], &load, 1);
        }
    _interval++;
}
@end
