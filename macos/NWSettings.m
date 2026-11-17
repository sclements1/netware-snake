#import "NWSettings.h"
#include <math.h>

NSString * const NWSettingsDidChangeNotification = @"NWNetWareSnakePreferencesChanged";
static const NSInteger NWSettingsVersion = 2;

static double NWClosestSpeed(double input) {
    if (!isfinite(input) || input <= 0) return 1.0;
    const double choices[] = {1.0, 0.5, 2.0};
    double result = choices[0], distance = fabs(input - choices[0]);
    for (NSUInteger i = 1; i < sizeof(choices) / sizeof(choices[0]); ++i) {
        double candidate = fabs(input - choices[i]);
        if (candidate < distance) { result = choices[i]; distance = candidate; }
    }
    return result;
}
static NSString *NWValidColor(id value) {
    if (![value isKindOfClass:NSString.class] || [value length] != 7 || ![value hasPrefix:@"#"])
        return @"#AA0000";
    NSCharacterSet *hex = [NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdefABCDEF"];
    if ([[value substringFromIndex:1] rangeOfCharacterFromSet:hex.invertedSet].location != NSNotFound)
        return @"#AA0000";
    return [value uppercaseString];
}
static NSMutableDictionary *NWDefaultProfile(BOOL smp) {
    NSMutableDictionary *profile = [@{@"screenMode":@0, @"size":@1, @"speed":@1.0,
        @"resolveGaps":@NO, @"eatDesktop":@NO, @"demo":@NO} mutableCopy];
    if (smp) { profile[@"cpuPolicy"] = @0; profile[@"colorStart"] = @0; }
    else profile[@"colorHex"] = @"#AA0000";
    return profile;
}

@implementation NWSettings {
    NSMutableDictionary *_profile312, *_profile42, *_profileModern;
    NWMode _mode;
}
@synthesize diagnostics = _diagnostics;
- (instancetype)init {
    self = [super init];
    if (self) { _mode = NWModeNetWare312; _profile312 = NWDefaultProfile(NO); _profile42 = NWDefaultProfile(YES); _profileModern = NWDefaultProfile(YES); _profileModern[@"screenMode"]=@2; }
    return self;
}
- (NSMutableDictionary *)activeProfile { return _mode == NWModeModern ? _profileModern : _mode == NWModeNetWare42 ? _profile42 : _profile312; }
- (NWMode)mode { return _mode; }
- (void)setMode:(NWMode)mode { _mode = mode >= 0 && mode <= 2 ? mode : NWModeNetWare312; }
- (NWScreenMode)screenMode { if(self.mode==NWModeModern)return NWScreenModeUnifiedDesktop; return (NWScreenMode)[self.activeProfile[@"screenMode"] integerValue]; }
- (void)setScreenMode:(NWScreenMode)value {
    self.activeProfile[@"screenMode"] = @(value >= 0 && value <= 2 ? value : NWScreenModeFourThirds);
}
- (NSInteger)size { return [self.activeProfile[@"size"] integerValue]; }
- (void)setSize:(NSInteger)value { self.activeProfile[@"size"] = @(value >= 0 && value <= 2 ? value : 1); }
- (double)speed { return [self.activeProfile[@"speed"] doubleValue]; }
- (void)setSpeed:(double)value { self.activeProfile[@"speed"] = @(NWClosestSpeed(value)); }
- (BOOL)resolveGaps { return [self.activeProfile[@"resolveGaps"] boolValue]; }
- (void)setResolveGaps:(BOOL)value { self.activeProfile[@"resolveGaps"] = @(value); }
- (BOOL)eatDesktop { return [self.activeProfile[@"eatDesktop"] boolValue]; }
- (void)setEatDesktop:(BOOL)value { self.activeProfile[@"eatDesktop"] = @(value); }
- (BOOL)demo { return [self.activeProfile[@"demo"] boolValue]; }
- (void)setDemo:(BOOL)value { self.activeProfile[@"demo"] = @(value); }
- (NSString *)colorHex { return _profile312[@"colorHex"]; }
- (void)setColorHex:(NSString *)value { _profile312[@"colorHex"] = NWValidColor(value); }
- (NWCPUPolicy)cpuPolicy { return (NWCPUPolicy)[(self.mode==NWModeModern?_profileModern:_profile42)[@"cpuPolicy"] integerValue]; }
- (void)setCpuPolicy:(NWCPUPolicy)value { (self.mode==NWModeModern?_profileModern:_profile42)[@"cpuPolicy"] = @(value >= 0 && value <= 2 ? value : NWCPUDetected31); }
- (NSInteger)colorStart { return [(self.mode==NWModeModern?_profileModern:_profile42)[@"colorStart"] integerValue]; }
- (void)setColorStart:(NSInteger)value { (self.mode==NWModeModern?_profileModern:_profile42)[@"colorStart"] = @(value >= 0 && value <= 31 ? value : 0); }
- (BOOL)allow32 { return self.cpuPolicy != NWCPUDetected31; }
- (void)setAllow32:(BOOL)value { self.cpuPolicy = value ? NWCPUDetected32 : NWCPUDetected31; }
+ (instancetype)defaults312 { return [self new]; }
+ (instancetype)defaults42 { NWSettings *settings = [self new]; settings.mode = NWModeNetWare42; return settings; }
+ (NSUInteger)paletteAttributeForCPU:(NSUInteger)cpu colorStart:(NSInteger)start {
    const NSUInteger palette[] = {12,9,10,11,13,7,4,1,2,3,6,14,5,8,15};
    NSUInteger offset = start >= 0 && start <= 31 ? (NSUInteger)start : 0;
    return palette[(cpu % 15 + offset % 15) % 15];
}
+ (NSString *)paletteColorNameForAttribute:(NSUInteger)attribute {
    NSArray<NSString *> *names = @[@"Black", @"Blue", @"Green", @"Cyan", @"Red", @"Magenta", @"Brown", @"Light gray",
        @"Dark gray", @"Bright blue", @"Bright green", @"Bright cyan", @"Bright red", @"Bright magenta", @"Yellow", @"White"];
    return attribute < names.count ? names[attribute] : names[0];
}
- (void)loadProfile:(id)dictionary mode:(NWMode)mode {
    if (![dictionary isKindOfClass:NSDictionary.class]) return;
    NWMode previous = self.mode; self.mode = mode;
    NSDictionary *d = dictionary;
    if ([d[@"screenMode"] isKindOfClass:NSNumber.class]) self.screenMode = [d[@"screenMode"] integerValue];
    if ([d[@"size"] isKindOfClass:NSNumber.class]) self.size = [d[@"size"] integerValue];
    if ([d[@"speed"] isKindOfClass:NSNumber.class]) self.speed = [d[@"speed"] doubleValue];
    if ([d[@"resolveGaps"] isKindOfClass:NSNumber.class]) self.resolveGaps = [d[@"resolveGaps"] boolValue];
    if ([d[@"eatDesktop"] isKindOfClass:NSNumber.class]) self.eatDesktop = [d[@"eatDesktop"] boolValue];
    if ([d[@"demo"] isKindOfClass:NSNumber.class]) self.demo = [d[@"demo"] boolValue];
    if (mode == NWModeNetWare312) {
        if (d[@"colorHex"]) self.colorHex = d[@"colorHex"];
    } else {
        if ([d[@"cpuPolicy"] isKindOfClass:NSNumber.class]) self.cpuPolicy = [d[@"cpuPolicy"] integerValue];
        if ([d[@"colorStart"] isKindOfClass:NSNumber.class]) self.colorStart = [d[@"colorStart"] integerValue];
    }
    self.mode = previous;
}
+ (instancetype)settingsWithDefaults:(NSUserDefaults *)defaults {
    NWSettings *settings = [self new];
    NSInteger version = [defaults integerForKey:@"settingsVersion"];
    if (version >= NWSettingsVersion) {
        [settings loadProfile:[defaults objectForKey:@"profile312"] mode:NWModeNetWare312];
        [settings loadProfile:[defaults objectForKey:@"profile42"] mode:NWModeNetWare42];
        [settings loadProfile:[defaults objectForKey:@"profileModern"] mode:NWModeModern];
        settings.mode = [defaults integerForKey:@"selectedMode"];
        settings.diagnostics = [defaults boolForKey:@"enableDiagnostics"];
    } else if (version == 1) {
        // v0.5 stored these controls for 3.12 even when 4.2 was selected.
        NSMutableDictionary *profile = [NSMutableDictionary dictionary];
        NSDictionary *keys = @{@"screenMode":@"screenMode", @"size":@"snakeSize", @"speed":@"animationSpeed",
            @"resolveGaps":@"resolveGaps", @"eatDesktop":@"eatDesktop", @"demo":@"cpuDemo"};
        for (NSString *key in keys) { id value = [defaults objectForKey:keys[key]]; if (value) profile[key] = value; }
        [settings loadProfile:profile mode:NWModeNetWare312];
        settings.allow32 = [defaults boolForKey:@"allow32Processors"];
        settings.mode = [defaults integerForKey:@"selectedMode"];
        settings.diagnostics = [defaults boolForKey:@"enableDiagnostics"];
    } else {
        // v0.4 index 1 was Customizable and 2 was SMP; neither is a new index.
        NSInteger oldMode = [defaults integerForKey:@"mode"];
        if (oldMode == 1) {
            settings.screenMode = [defaults boolForKey:@"wide"] ? NWScreenModeWidescreen : NWScreenModeFourThirds;
            settings.resolveGaps = [defaults boolForKey:@"overlap"];
            settings.demo = [defaults boolForKey:@"demo"];
            if ([defaults objectForKey:@"size"]) settings.size = [defaults integerForKey:@"size"];
            if ([defaults objectForKey:@"speed"]) settings.speed = [defaults doubleForKey:@"speed"];
            if ([defaults objectForKey:@"color"]) settings.colorHex = [defaults objectForKey:@"color"];
        } else if (oldMode == 2) {
            settings.mode = NWModeNetWare42;
            settings.allow32 = [defaults boolForKey:@"allow32"];
        }
        settings.diagnostics = [defaults boolForKey:@"diagnostics"];
    }
    return settings;
}
- (id)copyWithZone:(NSZone *)zone {
    NWSettings *copy = [[[self class] allocWithZone:zone] init];
    copy->_profile312 = [_profile312 mutableCopy]; copy->_profile42 = [_profile42 mutableCopy];
    copy->_profileModern=[_profileModern mutableCopy]; copy.mode = self.mode; copy.diagnostics = self.diagnostics;
    return copy;
}
- (void)resetCurrentModeToDefaults {
    if(self.mode==NWModeModern){_profileModern=NWDefaultProfile(YES);_profileModern[@"screenMode"]=@2;}
    else if (self.mode == NWModeNetWare42) _profile42 = NWDefaultProfile(YES);
    else _profile312 = NWDefaultProfile(NO);
}
- (void)saveToDefaults:(NSUserDefaults *)defaults {
    [defaults setObject:[_profile312 copy] forKey:@"profile312"];
    [defaults setObject:[_profile42 copy] forKey:@"profile42"];
    [defaults setObject:[_profileModern copy] forKey:@"profileModern"];
    [defaults setInteger:self.mode forKey:@"selectedMode"];
    [defaults setBool:self.diagnostics forKey:@"enableDiagnostics"];
    [defaults setInteger:NWSettingsVersion forKey:@"settingsVersion"];
    [defaults synchronize];
}
@end
