/* Native settings tests. All persistence uses a random test-only suite. */
#import <Foundation/Foundation.h>
#import "NWSettings.h"
#include <assert.h>
#include <math.h>

static void expectCommonDefaults(NWSettings *settings) {
    assert(settings.screenMode == NWScreenModeFourThirds);
    assert(settings.size == 1 && settings.speed == 1.0);
    assert(!settings.resolveGaps && !settings.eatDesktop && !settings.demo);
}
static NSDictionary *values(NSUserDefaults *defaults, NSString *domain) {
    return [defaults persistentDomainForName:domain] ?: @{};
}
int main(void) {
    @autoreleasepool {
        NSString *domain = [@"org.netwaresnake.tests.settings." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:domain];
        assert(defaults != nil); [defaults removePersistentDomainForName:domain];
        [defaults setPersistentDomain:@{@"mode":@0, @"wide":@YES, @"size":@2, @"speed":@2,
            @"overlap":@YES, @"demo":@YES, @"color":@"#0000FF", @"allow32":@YES} forName:domain];
        NSDictionary *before = values(defaults, domain);
        NWSettings *faithful = [NWSettings settingsWithDefaults:defaults];
        assert(faithful.mode == NWModeNetWare312); expectCommonDefaults(faithful);
        assert([faithful.colorHex isEqualToString:@"#AA0000"]);
        assert([before isEqualToDictionary:values(defaults, domain)]);
        assert([defaults objectForKey:@"settingsVersion"] == nil);

        // v0.4 Customizable's index 1 must not mean the new 4.2 index 1.
        [defaults setInteger:1 forKey:@"mode"]; [defaults setDouble:1.75 forKey:@"speed"];
        NWSettings *custom = [NWSettings settingsWithDefaults:defaults];
        assert(custom.mode == NWModeNetWare312 && custom.screenMode == NWScreenModeWidescreen);
        assert(custom.resolveGaps && custom.demo && custom.size == 2 && custom.speed == 2);
        assert([custom.colorHex isEqualToString:@"#0000FF"]);
        [defaults setDouble:0.75 forKey:@"speed"];
        assert([NWSettings settingsWithDefaults:defaults].speed == 1.0);
        [defaults setInteger:2 forKey:@"mode"];
        NWSettings *smp = [NWSettings settingsWithDefaults:defaults];
        assert(smp.mode == NWModeNetWare42 && smp.cpuPolicy == NWCPUDetected32); expectCommonDefaults(smp);

        // v0.5's shared flat presentation keys belonged to the 3.12 profile.
        [defaults setPersistentDomain:@{@"settingsVersion":@1, @"selectedMode":@1, @"screenMode":@2,
            @"snakeSize":@0, @"animationSpeed":@0.5, @"resolveGaps":@YES, @"eatDesktop":@YES,
            @"cpuDemo":@YES, @"allow32Processors":@YES, @"enableDiagnostics":@YES} forName:domain];
        before = values(defaults, domain);
        NWSettings *migrated = [NWSettings settingsWithDefaults:defaults];
        assert(migrated.mode == NWModeNetWare42 && migrated.cpuPolicy == NWCPUDetected32 && migrated.diagnostics);
        expectCommonDefaults(migrated);
        migrated.mode = NWModeNetWare312;
        assert(migrated.screenMode == NWScreenModeUnifiedDesktop && migrated.size == 0 && migrated.speed == 0.5);
        assert(migrated.resolveGaps && migrated.eatDesktop && migrated.demo);
        assert([migrated.colorHex isEqualToString:@"#AA0000"]);
        assert([before isEqualToDictionary:values(defaults, domain)]);

        // The two profiles and all copies own independent presentation choices.
        NWSettings *settings = [NWSettings defaults312];
        settings.screenMode = NWScreenModeUnifiedDesktop; settings.size = 0; settings.speed = 2;
        settings.eatDesktop = YES; settings.colorHex = @"#1234ab";
        settings.mode = NWModeNetWare42; expectCommonDefaults(settings);
        settings.screenMode = NWScreenModeWidescreen; settings.size = 2; settings.speed = 0.5;
        settings.resolveGaps = YES; settings.demo = YES; settings.cpuPolicy = NWCPUFixed32; settings.colorStart = 31;
        NWSettings *copy = [settings copy];
        copy.mode = NWModeNetWare312; copy.colorHex = @"#ABCDEF"; copy.speed = 1;
        settings.mode = NWModeNetWare312;
        assert([settings.colorHex isEqualToString:@"#1234AB"] && settings.speed == 2 && settings.size == 0);
        assert(settings.eatDesktop && !settings.resolveGaps && !settings.demo);
        settings.mode = NWModeNetWare42;
        assert(settings.speed == 0.5 && settings.resolveGaps && settings.demo && settings.cpuPolicy == NWCPUFixed32);
        assert(settings.colorStart == 31 && settings.allow32);
        settings.diagnostics = YES; [settings saveToDefaults:defaults];
        assert([defaults integerForKey:@"settingsVersion"] == 2);
        assert([defaults integerForKey:@"selectedMode"] == NWModeNetWare42);
        NWSettings *roundTrip = [NWSettings settingsWithDefaults:defaults];
        assert(roundTrip.mode == NWModeNetWare42 && roundTrip.cpuPolicy == NWCPUFixed32 && roundTrip.colorStart == 31);
        assert(roundTrip.screenMode == NWScreenModeWidescreen && roundTrip.size == 2 && roundTrip.speed == 0.5);
        assert(roundTrip.demo && roundTrip.resolveGaps && !roundTrip.eatDesktop && roundTrip.diagnostics);
        roundTrip.mode = NWModeNetWare312;
        assert(roundTrip.screenMode == NWScreenModeUnifiedDesktop && roundTrip.eatDesktop);
        assert([roundTrip.colorHex isEqualToString:@"#1234AB"] && roundTrip.speed == 2);

        // Restore only affects the current profile, including its own color/policy.
        roundTrip.mode = NWModeNetWare42; [roundTrip resetCurrentModeToDefaults];
        expectCommonDefaults(roundTrip); assert(roundTrip.cpuPolicy == NWCPUDetected31 && roundTrip.colorStart == 0);
        roundTrip.cpuPolicy = NWCPUDetected32; roundTrip.mode = NWModeNetWare312;
        assert([roundTrip.colorHex isEqualToString:@"#1234AB"] && roundTrip.eatDesktop);
        [roundTrip resetCurrentModeToDefaults]; expectCommonDefaults(roundTrip);
        assert([roundTrip.colorHex isEqualToString:@"#AA0000"] && roundTrip.cpuPolicy == NWCPUDetected32);

        // CPU positions continue the 15-color sequence across positions 15 and 31.
        const NSUInteger expected[] = {12,9,10,11,13,7,4,1,2,3,6,14,5,8,15};
        for (NSUInteger start = 0; start < 32; ++start)
            for (NSUInteger cpu = 0; cpu < 64; ++cpu)
                assert([NWSettings paletteAttributeForCPU:cpu colorStart:(NSInteger)start] == expected[(cpu + start) % 15]);
        assert([NWSettings paletteAttributeForCPU:0 colorStart:31] == 9);
        assert([[NWSettings paletteColorNameForAttribute:12] isEqualToString:@"Bright red"]);
        roundTrip.colorHex = @"not-a-color"; assert([roundTrip.colorHex isEqualToString:@"#AA0000"]);
        roundTrip.colorHex = @"#FFFFFG"; assert([roundTrip.colorHex isEqualToString:@"#AA0000"]);
        roundTrip.mode = NWModeModern; assert(roundTrip.mode == NWModeModern);
        assert(roundTrip.screenMode==NWScreenModeUnifiedDesktop);
        roundTrip.mode=NWModeNetWare312;
        roundTrip.size = 99; roundTrip.speed = NAN; roundTrip.screenMode = 99;
        assert(roundTrip.size == 1 && roundTrip.speed == 1 && roundTrip.screenMode == NWScreenModeFourThirds);
        roundTrip.cpuPolicy = 99; roundTrip.colorStart = 32;
        assert(roundTrip.cpuPolicy == NWCPUDetected31 && roundTrip.colorStart == 0);
        [defaults setInteger:99 forKey:@"selectedMode"];
        assert([NWSettings settingsWithDefaults:defaults].mode == NWModeNetWare312);
        assert([NWSettingsDidChangeNotification isEqualToString:@"NWNetWareSnakePreferencesChanged"]);
        [defaults removePersistentDomainForName:domain]; [defaults synchronize];
        puts("Native settings: v0.4/v0.5 migration, independent profiles, copy, persistence, reset, colors, 32 palette offsets and CPU policies PASS");
    }
    return 0;
}
