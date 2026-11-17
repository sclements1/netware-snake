#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NWMode) {
    NWModeNetWare312 = 0,
    NWModeNetWare42 = 1,
    NWModeModern = 2,
};
typedef NS_ENUM(NSInteger, NWScreenMode) {
    NWScreenModeFourThirds = 0,
    NWScreenModeWidescreen = 1,
    NWScreenModeUnifiedDesktop = 2,
};
typedef NS_ENUM(NSInteger, NWCPUPolicy) {
    NWCPUDetected31 = 0,
    NWCPUDetected32 = 1,
    NWCPUFixed32 = 2,
};

FOUNDATION_EXPORT NSString * const NWSettingsDidChangeNotification;

/* Each historical mode owns a separate profile. The common scalar properties
   access the selected mode's profile; copying preserves both profiles.
   Loading, including migration, is read-only. Only Save persists a draft. */
@interface NWSettings : NSObject <NSCopying>
@property(nonatomic) NWMode mode;
@property(nonatomic) NWScreenMode screenMode;
@property(nonatomic) NSInteger size;       // 0 Small, 1 Medium, 2 Large
@property(nonatomic) double speed;         // 0.5, 1, or 2
@property(nonatomic) BOOL resolveGaps;
@property(nonatomic) BOOL eatDesktop;
@property(nonatomic) BOOL demo;            // Remembered choice; Fixed 32 overrides it at runtime.
@property(nonatomic, copy) NSString *colorHex; // 3.12 profile only, default #AA0000.
@property(nonatomic) NWCPUPolicy cpuPolicy;    // 4.2 profile only.
@property(nonatomic) NSInteger colorStart;     // 4.2 historical palette position, 0..31.
@property(nonatomic) BOOL allow32;             // Compatibility alias for detected 31/32.
@property(nonatomic) BOOL diagnostics;         // Global troubleshooting preference.
+ (instancetype)settingsWithDefaults:(NSUserDefaults *)defaults;
+ (instancetype)defaults312;
+ (instancetype)defaults42;
+ (NSUInteger)paletteAttributeForCPU:(NSUInteger)cpu colorStart:(NSInteger)start;
+ (NSString *)paletteColorNameForAttribute:(NSUInteger)attribute;
- (void)resetCurrentModeToDefaults;
- (void)saveToDefaults:(NSUserDefaults *)defaults;
@end

NS_ASSUME_NONNULL_END
