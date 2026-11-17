#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import "NetWareSnakeView.h"
#import "NWSettings.h"
#import "NWUnifiedDesktopSession.h"
#import "NWWallpaperSnapshot.h"
#import "NWCPUReader.h"
#import "nw_geometry.h"
#import "nw_snake.h"

@interface NWFixtureView : NetWareSnakeView
@end
@implementation NWFixtureView
- (void)captureWallpaperIfNeeded {} // Synthetic wallpaper only; no user picture reads.
@end
// Exercise shared-world behavior even when a headless test host reports no screens.
@interface NWFixtureScreen : NSObject
@property NSRect frame;
@property(copy) NSDictionary *deviceDescription;
@end
@implementation NWFixtureScreen
@end
static nw_snake *Core(NetWareSnakeView *view) {
    Ivar ivar=class_getInstanceVariable(NetWareSnakeView.class,"_core");
    return *(nw_snake **)((uint8_t *)(__bridge void *)view+ivar_getOffset(ivar));
}
static nw4_session *SMP(NetWareSnakeView *view) {
    Ivar ivar=class_getInstanceVariable(NetWareSnakeView.class,"_smp");
    return *(nw4_session **)((uint8_t *)(__bridge void *)view+ivar_getOffset(ivar));
}
static NSImage *WhiteImage(void) {
    NSImage *image=[[NSImage alloc] initWithSize:NSMakeSize(64,64)];
    [image lockFocus];[NSColor.whiteColor setFill];NSRectFill(NSMakeRect(0,0,64,64));[image unlockFocus];return image;
}
static NSBitmapImageRep *Render(NSView *view) {
    [view display];
    NSBitmapImageRep *bitmap=[view bitmapImageRepForCachingDisplayInRect:view.bounds];
    NSCAssert(bitmap,@"No bitmap");[view cacheDisplayInRect:view.bounds toBitmapImageRep:bitmap];return bitmap;
}
static NSUInteger BlackSamples(NSBitmapImageRep *bitmap) {
    NSUInteger n=0;
    for(NSInteger y=5;y<bitmap.pixelsHigh;y+=5)for(NSInteger x=5;x<bitmap.pixelsWide;x+=5) {
        NSColor *c=[[bitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        if(c.redComponent<0.02 && c.greenComponent<0.02 && c.blueComponent<0.02)n++;
    }
    return n;
}
static BOOL HasBlue(NSBitmapImageRep *bitmap) {
    for(NSInteger y=0;y<bitmap.pixelsHigh;y+=5)for(NSInteger x=0;x<bitmap.pixelsWide;x+=5) {
        NSColor *c=[[bitmap colorAtX:x y:y] colorUsingColorSpace:NSColorSpace.deviceRGBColorSpace];
        if(c.blueComponent>0.9 && c.redComponent<0.1)return YES;
    }
    return NO;
}
int main(int argc,char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSString *name=[@"org.netwaresnake.tests.view." stringByAppendingString:NSUUID.UUID.UUIDString];
        NSUserDefaults *defaults=[[NSUserDefaults alloc] initWithSuiteName:name];
        NWSettings *settings=NWSettings.defaults312;settings.screenMode=NWScreenModeWidescreen;
        [settings saveToDefaults:defaults];
        NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(60,60,800,480)
            styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
        window.releasedWhenClosed=NO;
        NWFixtureView *view=[[NWFixtureView alloc] initWithFrame:NSMakeRect(0,0,800,480) isPreview:NO defaults:defaults];
        window.contentView=view;[window orderFront:nil];[view startAnimation];
        nw_snake *core=Core(view);NSCAssert(core,@"Core missing");
        int centerX=nw_snake_x(core),centerY=nw_snake_y(core);
        for(int i=0;i<100;i++)nw_snake_advance(core,100);
        [view stopAnimation];[view startAnimation];
        NSCAssert(nw_snake_x(Core(view))==centerX && nw_snake_y(Core(view))==centerY,@"Wide restart lost center");
        // EatDesktop must retain a black trail after all currently visible glyphs leave it.
        settings.eatDesktop=YES;settings.demo=YES;[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        [view stopAnimation];[view startAnimation];
        NWWallpaperSnapshot *wallpaper=[[NWWallpaperSnapshot alloc] initWithImage:WhiteImage()
            options:@{NSWorkspaceDesktopImageScalingKey:@(NSImageScaleAxesIndependently)} canvasSize:NSMakeSize(800,480)];
        [view setValue:wallpaper forKey:@"wallpaper"];
        NSBitmapImageRep *before=Render(view);NSCAssert(BlackSamples(before)==0,@"Untouched wallpaper not visible");
        for(int i=0;i<130;i++)nw_snake_advance(Core(view),100);
        NSBitmapImageRep *after=Render(view);NSCAssert(BlackSamples(after)>100,@"Consumed tail failed to stay black");
        if(argc>1)[[after representationUsingType:NSBitmapImageFileTypePNG properties:@{}]
            writeToFile:[NSString stringWithUTF8String:argv[1]] atomically:YES];
        const uint8_t *visited=nw_snake_visited(Core(view));size_t cells=(size_t)nw_snake_columns(Core(view))*nw_snake_rows(Core(view));
        NSData *mask=[NSData dataWithBytes:visited length:cells];
        settings.resolveGaps=YES;[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        NSCAssert([mask isEqualToData:[NSData dataWithBytes:nw_snake_visited(Core(view)) length:cells]],@"Resolve gaps cleared eaten trail");
        nw_snake *identity312=Core(view);
        settings.colorHex=@"#0055FF";[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        NSCAssert(Core(view)==identity312 &&
            [mask isEqualToData:[NSData dataWithBytes:nw_snake_visited(Core(view)) length:cells]],@"Color change reset the animation");
        NSCAssert(HasBlue(Render(view)),@"3.12 custom color did not reach glyph rendering");
        // Historical medium4:3 origin survives all the UI migration work.
        settings.screenMode=NWScreenModeFourThirds;settings.size=1;settings.eatDesktop=NO;
        [settings saveToDefaults:defaults];[[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        [view stopAnimation];[view startAnimation];
        NSCAssert(nw_snake_columns(Core(view))==80 && nw_snake_rows(Core(view))==25,@"Medium4:3 grid changed");
        NSCAssert(nw_snake_x(Core(view))==38 && nw_snake_y(Core(view))==12,@"Historical origin changed");
        // All 4.2 options run through the same native view, including forced virtual CPUs.
        settings.mode=NWModeNetWare42;settings.screenMode=NWScreenModeWidescreen;
        settings.size=0;settings.eatDesktop=YES;settings.cpuPolicy=NWCPUFixed32;
        settings.colorStart=5;settings.demo=NO;[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        [view stopAnimation];[view startAnimation];[view setValue:wallpaper forKey:@"wallpaper"];
        nw4_session *smp=SMP(view);
        NSCAssert(smp && nw4_session_processors(smp)==32,@"Fixed 32 did not create 32 snakes");
        NSCAssert(nw4_session_columns(smp)>80 && nw4_session_rows(smp)==34,@"4.2 ignored geometry or size");
        NSCAssert(BlackSamples(Render(view))==0,@"4.2 wallpaper missing before first paint");
        unsigned loads[32];for(unsigned p=0;p<32;p++)loads[p]=75;
        nw4_session_tick(smp,loads,32);
        size_t smpCells=(size_t)nw4_session_columns(smp)*nw4_session_rows(smp);
        BOOL painted=NO;
        for(size_t c=0;c<smpCells;c++)if(nw4_session_characters(smp)[c]!=32) {
            painted=YES;NSCAssert(nw4_session_attributes(smp)[c]==7,@"CPU 0 starting color was ignored");
        }
        NSCAssert(painted,@"CPU 0 did not paint");
        for(unsigned i=1;i<250;i++)nw4_session_tick(smp,loads,32);
        NSCAssert(BlackSamples(Render(view))>100,@"4.2 did not consume wallpaper");
        NSData *smpMask=[NSData dataWithBytes:nw4_session_visited(smp) length:smpCells];
        settings.resolveGaps=YES;[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        NSCAssert(SMP(view)==smp && [smpMask isEqualToData:[NSData dataWithBytes:nw4_session_visited(smp) length:smpCells]],
            @"4.2 resolve gaps discarded eaten cells");
        __block NSUInteger measuredReads=0;
        Method loadsMethod=class_getInstanceMethod(NWCPUReader.class,@selector(processorUsagesAtTime:));
        IMP fixtureLoads=imp_implementationWithBlock(^NSArray *(id receiver,CFTimeInterval time) {
            (void)receiver;(void)time;measuredReads++;return @[@10,@90];
        });
        IMP originalLoads=method_setImplementation(loadsMethod,fixtureLoads);
        uint64_t interval=nw4_session_intervals(smp);
        [view setValue:@(CACurrentMediaTime()-0.2) forKey:@"lastFrameTime"];
        [view animateOneFrame];
        NSCAssert(nw4_session_intervals(smp)>interval && measuredReads==0,@"Fixed 32 used measured CPU loads");
        settings.cpuPolicy=NWCPUDetected31;[settings saveToDefaults:defaults];
        [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
        [view setValue:@(CACurrentMediaTime()-0.2) forKey:@"lastFrameTime"];[view animateOneFrame];
        NSCAssert(measuredReads>0,@"Detected CPUs did not restore measured source");
        method_setImplementation(loadsMethod,originalLoads);imp_removeBlock(fixtureLoads);
        [view stopAnimation];[window orderOut:nil];
        {
            NWFixtureScreen *left=[NWFixtureScreen new],*right=[NWFixtureScreen new];
            left.frame=NSMakeRect(-1280,0,1280,800);left.deviceDescription=@{@"NSScreenNumber":@1};
            right.frame=NSMakeRect(0,0,1920,1080);right.deviceDescription=@{@"NSScreenNumber":@2};
            NSArray *fixtureScreens=@[left,right];
            Method screensMethod=class_getClassMethod(NSScreen.class,@selector(screens));
            IMP fixtureIMP=imp_implementationWithBlock(^NSArray *(id receiver) {
                (void)receiver;return fixtureScreens;
            });
            IMP originalIMP=method_setImplementation(screensMethod,fixtureIMP);
            NWSettings *unified=NWSettings.defaults312;unified.screenMode=NWScreenModeUnifiedDesktop;
            NSObject *a=[NSObject new],*b=[NSObject new];
            NWUnifiedDesktopSession *world=[NWUnifiedDesktopSession acquireForSettings:unified participant:a];
            NSCAssert(world,@"Unified desktop failed");
            NSCAssert(world==[NWUnifiedDesktopSession acquireForSettings:unified participant:b],@"Separate worlds per display");
            CFTimeInterval now=CACurrentMediaTime();
            for(int i=1;i<=150;i++)[world advanceAtTime:now+i/18.2];
            nw_snake *identity=world.core;uint64_t passes=nw_snake_passes(identity);
            [world advanceAtTime:now+150/18.2];
            NSCAssert(nw_snake_passes(identity)==passes,@"Second display doubled the shared clock");
            unified.resolveGaps=YES;unified.speed=2;unified.demo=YES;
            NSCAssert(world==[NWUnifiedDesktopSession acquireForSettings:unified participant:a],@"Presentation change reset unified world");
            NSCAssert(identity==world.core && nw_snake_passes(world.core)==passes,@"Unified state was discarded");
            [world detachParticipant:a];
            NSCAssert(world==[NWUnifiedDesktopSession acquireForSettings:unified participant:b],@"Other display lost world");
            [world detachParticipant:b];
            NWUnifiedDesktopSession *fresh=[NWUnifiedDesktopSession acquireForSettings:unified participant:a];
            NSCAssert(fresh!=world && nw_snake_passes(fresh.core)==0,@"New activation retained old world");
            [fresh detachParticipant:a];
            unified.mode=NWModeNetWare42;unified.screenMode=NWScreenModeUnifiedDesktop;
            unified.cpuPolicy=NWCPUFixed32;unified.colorStart=31;unified.demo=NO;
            NWUnifiedDesktopSession *smpWorld=[NWUnifiedDesktopSession acquireForSettings:unified participant:a];
            NSCAssert(smpWorld && smpWorld.smp && !smpWorld.core && nw4_session_processors(smpWorld.smp)==32,
                @"Unified 4.2 did not use a shared 32-CPU world");
            NSCAssert(smpWorld==[NWUnifiedDesktopSession acquireForSettings:unified participant:b],@"4.2 split the unified world");
            CFTimeInterval smpNow=CACurrentMediaTime();
            for(int i=1;i<=200;i++)[smpWorld advanceAtTime:smpNow+i/18.2];
            uint64_t smpIntervals=nw4_session_intervals(smpWorld.smp);
            [smpWorld advanceAtTime:smpNow+200/18.2];
            NSCAssert(smpIntervals==nw4_session_intervals(smpWorld.smp),@"4.2 multiple views doubled the clock");
            unified.resolveGaps=YES;unified.speed=2;unified.demo=YES;
            NSCAssert(smpWorld==[NWUnifiedDesktopSession acquireForSettings:unified participant:a] &&
                smpIntervals==nw4_session_intervals(smpWorld.smp),@"4.2 presentation settings discarded shared state");
            [smpWorld detachParticipant:a];[smpWorld detachParticipant:b];
            method_setImplementation(screensMethod,originalIMP);
            imp_removeBlock(fixtureIMP);
        }
        [defaults removePersistentDomainForName:name];
        puts("PASS native view: custom color, both-mode geometry/wallpaper/gaps, Fixed 32 simulation, measured restore, historical origin and shared worlds");
    }
    return 0;
}
