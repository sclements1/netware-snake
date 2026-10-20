#import "NetWareSnakeView.h"
#import "NWCPUReader.h"
#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <ScreenSaver/ScreenSaver.h>
#import <math.h>
#import <stdlib.h>
#import <stdint.h>
#import <stdarg.h>
#import <os/log.h>
#import "nw_snake.h"
#import "nw_geometry.h"

static NSString * const NWModuleID=@"org.netwaresnake.mac.saver";
static NSString * const NWBuildTag=@"0.3.0";
static NSString * const NWChangedNotification=@"NWNetWareSnakePreferencesChanged";
static const int NWBandDemo[9]={5,17,28,44,75,44,28,17,5};

/* Apple unified logging: silent except for actionable errors unless diagnostics
   are explicitly enabled. No per-frame, CPU-sample, or user-file-path logging. */
static os_log_t NWLogHandle(void) {
    static os_log_t log;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ log=os_log_create("org.netwaresnake.mac.saver", "runtime"); });
    return log;
}
static void NWLogDiagnostic(BOOL enabled, NSString *format, ...) {
    if (!enabled)return;
    va_list args;
    va_start(args,format);
    NSString *message=[[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);
    os_log_info(NWLogHandle(), "%{public}@", message);
}
static void NWLogFailure(NSString *message) {
    os_log_error(NWLogHandle(), "%{public}@", message);
}

static NSString *NWColorHex(NSColor *input) {
    NSColor *rgb=[input colorUsingColorSpace:[NSColorSpace deviceRGBColorSpace]];
    if (!rgb)return @"#AA0000";
    return [NSString stringWithFormat:@"#%02X%02X%02X",
        (unsigned)lround(fmax(0,fmin(1,rgb.redComponent))*255),
        (unsigned)lround(fmax(0,fmin(1,rgb.greenComponent))*255),
        (unsigned)lround(fmax(0,fmin(1,rgb.blueComponent))*255)];
}
static void NWParseRGB(NSString *hex,uint8_t result[3]) {
    unsigned value=0xAA0000;
    if ([hex isKindOfClass:[NSString class]] && [hex length]==7 && [hex hasPrefix:@"#"]) {
        unsigned parsed=0;
        NSScanner *scanner=[NSScanner scannerWithString:[hex substringFromIndex:1]];
        if ([scanner scanHexInt:&parsed] && [scanner isAtEnd]) value=parsed;
    }
    result[0]=(uint8_t)(value>>16);result[1]=(uint8_t)(value>>8);result[2]=(uint8_t)value;
}
static BOOL NWBitmapPixel(uint8_t glyph,int x,int y) {
    if (glyph==0xdb)return YES;
    if (glyph==0xb2)return (x%2==0 || y%2==0);
    if (glyph==0xb1)return ((x+y)%2==0);
    if (glyph==0xb0)return (x%2==0 && y%2==0);
    return NO;
}

@interface NetWareSnakeView ()
- (void)applyPreferences;
- (void)onSettingsChanged:(NSNotification *)notification;
@end
@implementation NetWareSnakeView {
    nw_snake *_core;
    CGImageRef _shadeImages[4];
    uint8_t _lastColor[3];
    uint32_t _initialSeed;
    int _columns, _rows, _mode, _size;
    BOOL _widescreen, _overlap, _demo, _diagnostics;
    BOOL _reportedCoreFailure;
    double _speed;
    CFTimeInterval _lastFrameTime, _startTime, _lastPrefsRead;
    double _accumulator;
    BOOL _firstPrefs;
    ScreenSaverDefaults *_defaults;
    NSPanel *_panel;
    NSPopUpButton *_modePopup,*_sizePopup,*_speedPopup,*_sourcePopup;
    NSButton *_wideBox,*_overlapBox,*_resetButton,*_diagnosticsBox;
    NSColorWell *_colorWell;
}
- (instancetype)initWithFrame:(NSRect)frame isPreview:(BOOL)isPreview {
    self=[super initWithFrame:frame isPreview:isPreview];
    if(self) {
        self.animationTimeInterval=1.0/30.0; // presentation tick; simulation remains 18.2 Hz
        _initialSeed=arc4random() ^ (uint32_t)(uintptr_t)self;
        _defaults=[ScreenSaverDefaults defaultsForModuleWithName:NWModuleID];
        [_defaults registerDefaults:@{@"mode":@0,@"wide":@YES,@"color":@"#AA0000",
            @"size":@1,@"speed":@1.0,@"overlap":@NO,@"demo":@NO,
            @"diagnostics":@NO}];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSettingsChanged:)
               name:NWChangedNotification object:nil];
        _lastColor[0]=_lastColor[1]=_lastColor[2]=0xff;
        _startTime=CACurrentMediaTime();
        [self applyPreferences];
        NWLogDiagnostic(_diagnostics,@"INIT build=%@ preview=%d size=%.0fx%.0f",
                        NWBuildTag,isPreview,frame.size.width,frame.size.height);
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    nw_snake_destroy(_core);
    for(int i=0;i<4;i++)if(_shadeImages[i])CGImageRelease(_shadeImages[i]);
}
- (BOOL)isFlipped {return YES;}
- (void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    if(_defaults)[self applyPreferences];
    /* Grid count can stay 80x25 even when the host resizes the view.
       Repaint so the centered VGA viewport gets its new letterboxing. */
    [self setNeedsDisplay:YES];
}
/* View attachment is informational; the rendering geometry is derived
   solely from bounds and the selected mode, never the host monitor size. */
- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    NWLogDiagnostic(_diagnostics,@"ATTACH display=%@ attached=%d",
                    self.window.screen.deviceDescription[@"NSScreenNumber"],self.window!=nil);
}
- (void)onSettingsChanged:(NSNotification *)notification {
    (void)notification;
    [_defaults synchronize];
    [self applyPreferences];
}
- (void)rebuildGlyphImagesForColor:(const uint8_t *)color {
    if(memcmp(color,_lastColor,3)==0 && _shadeImages[0])return;
    memcpy(_lastColor,color,3);
    CGColorSpaceRef space=CGColorSpaceCreateDeviceRGB();
    const uint8_t patterns[4]={0xdb,0xb2,0xb1,0xb0};
    for(int i=0;i<4;i++) {
        if(_shadeImages[i]){CGImageRelease(_shadeImages[i]);_shadeImages[i]=NULL;}
        uint8_t pixels[8*16*4];memset(pixels,0,sizeof pixels);
        for(int y=0;y<16;y++)for(int x=0;x<8;x++) {
            if(NWBitmapPixel(patterns[i],x,y)) {
                uint8_t *pixel=&pixels[(y*8+x)*4];
                pixel[0]=color[0];pixel[1]=color[1];pixel[2]=color[2];pixel[3]=255;
            }
        }
        CGContextRef bitmap=CGBitmapContextCreate(pixels,8,16,8,8*4,space,
                      kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
        if(bitmap) {_shadeImages[i]=CGBitmapContextCreateImage(bitmap);CGContextRelease(bitmap);}
    }
    CGColorSpaceRelease(space);
}
- (void)applyPreferences {
    BOOL first=!_firstPrefs;
    _firstPrefs=YES;
    int mode=(int)[_defaults integerForKey:@"mode"];
    mode=(mode==1)?1:0;
    int size=(int)[_defaults integerForKey:@"size"];
    if(size<0||size>2)size=1;
    /* Faithful mode never inherits configurable geometry or presentation
       preferences, even if those preferences remain stored from earlier runs. */
    BOOL widescreen=mode==1 && [_defaults boolForKey:@"wide"];
    BOOL overlap=mode==1 && [_defaults boolForKey:@"overlap"];
    BOOL demo=mode==1 && [_defaults boolForKey:@"demo"];
    BOOL diagnostics=[_defaults boolForKey:@"diagnostics"];
    double speed=mode==1?[_defaults doubleForKey:@"speed"]:1.0;
    if(speed<0.5||speed>2.0)speed=1.0;
    uint8_t color[3];
    NWParseRGB(mode==0?@"#AA0000":[_defaults stringForKey:@"color"],color);
    BOOL colorChanged=memcmp(color,_lastColor,3)!=0;
    NSSize viewSize=self.bounds.size;
    int columns=80,rows=25;
    nw_grid_for_view(viewSize.width,viewSize.height,mode==0,widescreen,size,&columns,&rows);
    BOOL geometryChanged=(first || !_core || columns!=_columns || rows!=_rows);
    BOOL changed=first || geometryChanged || mode!=_mode || size!=_size ||
                 widescreen!=_widescreen || overlap!=_overlap || demo!=_demo ||
                 speed!=_speed || colorChanged;
    BOOL logStateChanged=(first || diagnostics!=_diagnostics);
    _mode=mode;_size=size;_widescreen=widescreen;_overlap=overlap;_demo=demo;_speed=speed;
    _diagnostics=diagnostics;
    if (logStateChanged && !first)
        NWLogDiagnostic(_diagnostics,@"DIAGNOSTICS enabled");
    if (changed)
        NWLogDiagnostic(_diagnostics,@"PREFS mode=%d grid=%dx%d demo=%d overlap=%d speed=%.2f",
                        mode,columns,rows,demo,overlap,speed);
    if(geometryChanged) {
        nw_snake *newCore=nw_snake_create(columns,rows,_initialSeed);
        if(newCore) {
            nw_snake_destroy(_core);_core=newCore;_columns=columns;_rows=rows;_accumulator=0;
            _reportedCoreFailure=NO;
        } else if (!_reportedCoreFailure) {
            NWLogFailure(@"Failed to allocate snake simulation state");
            _reportedCoreFailure=YES;
        }
    }
    if (colorChanged || first) [self rebuildGlyphImagesForColor:color];
    if (changed)[self setNeedsDisplay:YES];
}
- (void)startAnimation {
    NWLogDiagnostic(_diagnostics,@"START build=%@ mode=%d grid=%dx%d display=%@",
                    NWBuildTag,_mode,_columns,_rows,
                    self.window.screen.deviceDescription[@"NSScreenNumber"]);
    _lastFrameTime=CACurrentMediaTime();
    _startTime=_lastFrameTime;
    _accumulator=0;
    [super startAnimation];
}
- (void)stopAnimation {
    NWLogDiagnostic(_diagnostics,@"STOP build=%@",NWBuildTag);
    [super stopAnimation];
    _lastFrameTime=0;
}
- (void)animateOneFrame {
    /* Important on recent macOS: do no work for a view no longer attached
       to a window. Host lifecycle issues remain outside plug-in control. */
    if (!self.window || [self isHiddenOrHasHiddenAncestor])return;
    const CFTimeInterval now=CACurrentMediaTime();
    if(now-_lastPrefsRead>2.0) {
        _lastPrefsRead=now;
        [_defaults synchronize];
        [self applyPreferences];
    }
    if(!_core)return;
    if(!_lastFrameTime){_lastFrameTime=now;return;}
    double dt=now-_lastFrameTime;_lastFrameTime=now;
    if(dt<0)dt=0;
    if(dt>0.25)dt=0.25; // no burst after machine sleep or delayed UI
    _accumulator+=dt*_speed*(double)NW_SNAKE_HZ_NUM/(double)NW_SNAKE_HZ_DEN;
    int cpu=0;
    if(_demo) {
        int stage=(int)floor((now-_startTime)/5.0)%9;
        cpu=NWBandDemo[stage<0?0:stage];
    } else cpu=(int)lround([[NWCPUReader sharedReader] aggregateUsageAtTime:now]);
    BOOL redraw=NO;
    for(int n=0;_accumulator>=1.0 && n<8;n++) {
        unsigned changed=nw_snake_advance(_core,cpu);
        _accumulator-=1.0;
        if(changed & (_overlap?NW_PROTECTED_CHANGED:NW_FRAME_CHANGED)) redraw=YES;
    }
    if(_accumulator>8.0)_accumulator=0; // safe bound, no runaway catchup
    if(redraw)[self setNeedsDisplay:YES];
}
- (void)drawRect:(NSRect)dirtyRect {
    (void)dirtyRect;
    CGContextRef ctx=NSGraphicsContext.currentContext.CGContext;
    if(!ctx)return;
    const NSRect bounds=self.bounds;
    CGContextSetRGBFillColor(ctx,0,0,0,1);
    CGContextFillRect(ctx,NSRectToCGRect(bounds));
    if(!_core)return;
    double cw=0,ch=0,ox=0,oy=0;
    nw_grid_metrics_for_mode(bounds.size.width,bounds.size.height,
        _columns,_rows,_mode==0,&cw,&ch,&ox,&oy);
    if(cw<=0||ch<=0)return;
    /* The Faithful renderer is a centered 640x480 logical VGA viewport.
       Its 80x25, 8x16 pixel text grid occupies the middle 640x400 area.
       The remaining black 40 scanlines at top and bottom plus pillarboxing
       ensure an invariant 4:3 presentation on every physical screen. */
    CGContextSetInterpolationQuality(ctx,kCGInterpolationNone);
    CGContextSetShouldAntialias(ctx,false);
    const uint8_t *frame=nw_snake_frame(_core,_overlap);
    for(int y=0;y<_rows;y++)for(int x=0;x<_columns;x++) {
        uint8_t glyph=frame[(size_t)y*(size_t)_columns+(size_t)x];
        CGImageRef image=NULL;
        if(glyph==0xdb)image=_shadeImages[0];
        else if(glyph==0xb2)image=_shadeImages[1];
        else if(glyph==0xb1)image=_shadeImages[2];
        else if(glyph==0xb0)image=_shadeImages[3];
        if(image) CGContextDrawImage(ctx,CGRectMake(ox+x*cw,oy+y*ch,cw,ch),image);
    }
}
#pragma mark - Native ScreenSaver settings sheet
- (BOOL)hasConfigureSheet {return YES;}
- (NSTextField *)addLabel:(NSString *)text y:(CGFloat)y content:(NSView *)content {
    NSTextField *label=[NSTextField labelWithString:text];
    label.frame=NSMakeRect(20,y,168,24);
    [content addSubview:label];return label;
}
- (NSWindow *)configureSheet {
    if(_panel)return _panel;
    _panel=[[NSPanel alloc] initWithContentRect:NSMakeRect(0,0,535,470)
             styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    [_panel setTitle:@"NetWare Snake Settings"];
    NSView *v=_panel.contentView;
    [self addLabel:@"Mode" y:414 content:v];
    _modePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(185,411,330,27) pullsDown:NO];
    [_modePopup addItemsWithTitles:@[@"NetWare 3.12 Faithful",@"NetWare 3.12 Customizable"]];
    [_modePopup selectItemAtIndex:(_mode==1?1:0)];
    [_modePopup setTarget:self];[_modePopup setAction:@selector(settingModeChanged:)];[v addSubview:_modePopup];
    _wideBox=[[NSButton alloc] initWithFrame:NSMakeRect(185,372,330,24)];
    [_wideBox setButtonType:NSButtonTypeSwitch];[_wideBox setTitle:@"Extend the grid across widescreen displays"];
    [_wideBox setState:[_defaults boolForKey:@"wide"]?NSControlStateValueOn:NSControlStateValueOff];[v addSubview:_wideBox];
    [self addLabel:@"Snake color" y:335 content:v];
    _colorWell=[[NSColorWell alloc] initWithFrame:NSMakeRect(185,329,83,32)];
    uint8_t rgb[3];NWParseRGB([_defaults stringForKey:@"color"],rgb);
    _colorWell.color=[NSColor colorWithDeviceRed:rgb[0]/255.0 green:rgb[1]/255.0 blue:rgb[2]/255.0 alpha:1];
    [v addSubview:_colorWell];
    [self addLabel:@"Character size" y:293 content:v];
    _sizePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(185,289,330,27) pullsDown:NO];
    [_sizePopup addItemsWithTitles:@[@"Small (more cells)",@"Standard",@"Large"]];
    [_sizePopup selectItemAtIndex:MIN(2,MAX(0,(int)[_defaults integerForKey:@"size"]))];[v addSubview:_sizePopup];
    [self addLabel:@"Animation speed" y:252 content:v];
    _speedPopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(185,247,330,27) pullsDown:NO];
    [_speedPopup addItemsWithTitles:@[@"0.5×",@"0.75×",@"1× (18.2 Hz)",@"1.25×",@"1.5×",@"2×"]];
    const double speeds[]={0.5,0.75,1.0,1.25,1.5,2.0};
    int closest=2;double d=999;
    for(int i=0;i<6;i++)if(fabs(speeds[i]-[_defaults doubleForKey:@"speed"])<d){closest=i;d=fabs(speeds[i]-[_defaults doubleForKey:@"speed"]);}
    [_speedPopup selectItemAtIndex:closest];[v addSubview:_speedPopup];
    _overlapBox=[[NSButton alloc] initWithFrame:NSMakeRect(185,208,330,24)];
    [_overlapBox setButtonType:NSButtonTypeSwitch];[_overlapBox setTitle:@"Prevent original self-crossing gaps"];
    [_overlapBox setState:[_defaults boolForKey:@"overlap"]?NSControlStateValueOn:NSControlStateValueOff];[v addSubview:_overlapBox];
    [self addLabel:@"CPU load source" y:175 content:v];
    _sourcePopup=[[NSPopUpButton alloc] initWithFrame:NSMakeRect(185,171,330,27) pullsDown:NO];
    [_sourcePopup addItemsWithTitles:@[@"Live macOS aggregate CPU (default)",@"Demo: sweep through five bands"]];
    [_sourcePopup selectItemAtIndex:[_defaults boolForKey:@"demo"]?1:0];[v addSubview:_sourcePopup];
    _diagnosticsBox=[[NSButton alloc] initWithFrame:NSMakeRect(20,126,495,24)];
    [_diagnosticsBox setButtonType:NSButtonTypeSwitch];
    [_diagnosticsBox setTitle:@"Enable diagnostic logging (troubleshooting only)"];
    [_diagnosticsBox setState:[_defaults boolForKey:@"diagnostics"]?NSControlStateValueOn:NSControlStateValueOff];
    [v addSubview:_diagnosticsBox];
    NSTextField *hint=[NSTextField labelWithString:@"Faithful: fixed 80×25 grid, centered 4:3 VGA presentation."];
    hint.frame=NSMakeRect(20,89,495,22);
    hint.font=[NSFont systemFontOfSize:11];hint.textColor=[NSColor secondaryLabelColor];
    [v addSubview:hint];
    _resetButton=[[NSButton alloc] initWithFrame:NSMakeRect(20,38,148,30)];
    _resetButton.title=@"Restore Defaults…";_resetButton.bezelStyle=NSBezelStyleRounded;
    _resetButton.target=self;_resetButton.action=@selector(restoreCustomDefaults:);[v addSubview:_resetButton];
    NSButton *cancel=[[NSButton alloc] initWithFrame:NSMakeRect(327,38,90,30)];
    cancel.title=@"Cancel";cancel.bezelStyle=NSBezelStyleRounded;
    cancel.target=self;cancel.action=@selector(cancelSettings:);[v addSubview:cancel];
    NSButton *save=[[NSButton alloc] initWithFrame:NSMakeRect(425,38,90,30)];
    save.title=@"Save";save.bezelStyle=NSBezelStyleRounded;
    save.keyEquivalent=@"\r";save.target=self;save.action=@selector(saveSettings:);[v addSubview:save];
    /* Bundle-local metadata: ScreenSaverEngine's mainBundle is NOT our saver.
       Always resolve version/build from the class's owning bundle. */
    NSBundle *bundle=[NSBundle bundleForClass:[NetWareSnakeView class]];
    NSString *version=[bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]?:@"unknown";
    NSString *build=[bundle objectForInfoDictionaryKey:@"CFBundleVersion"]?:@"?";
    NSTextField *footer=[NSTextField labelWithString:
        [NSString stringWithFormat:@"NetWare Snake v%@ · build %@",version,build]];
    footer.frame=NSMakeRect(20,7,495,18);
    footer.alignment=NSTextAlignmentCenter;
    footer.font=[NSFont systemFontOfSize:11];
    footer.textColor=[NSColor tertiaryLabelColor];
    [v addSubview:footer];
    [self settingModeChanged:nil];return _panel;
}
- (void)settingModeChanged:(id)sender {
    BOOL editable=(_modePopup.indexOfSelectedItem==1);
    /* A checked-but-disabled Widescreen box misleadingly suggests the
       historical picture is stretched. Show it OFF while in Faithful mode;
       restore the saved Customizable value when switching back. */
    if (!editable) [_wideBox setState:NSControlStateValueOff];
    else if (sender==_modePopup) {
        [_wideBox setState:[_defaults boolForKey:@"wide"]?
            NSControlStateValueOn:NSControlStateValueOff];
    }
    [_wideBox setEnabled:editable];[_colorWell setEnabled:editable];
    [_sizePopup setEnabled:editable];[_speedPopup setEnabled:editable];
    [_overlapBox setEnabled:editable];[_sourcePopup setEnabled:editable];
    [_resetButton setEnabled:editable];
}
- (void)restoreCustomDefaults:(id)sender {
    (void)sender;
    if (_modePopup.indexOfSelectedItem!=1)return;
    NSAlert *alert=[[NSAlert alloc] init];
    alert.messageText=@"Restore Customizable defaults?";
    alert.informativeText=@"Widescreen on, original red, standard size, 1× speed, historical crossing gaps, and live CPU. Faithful mode is unchanged.";
    [alert addButtonWithTitle:@"Restore Defaults"];
    [alert addButtonWithTitle:@"Cancel"];
    NSModalResponse answer=[alert runModal];
    if(answer!=NSAlertFirstButtonReturn)return;
    [_wideBox setState:NSControlStateValueOn];
    _colorWell.color=[NSColor colorWithDeviceRed:170.0/255.0 green:0 blue:0 alpha:1];
    [_sizePopup selectItemAtIndex:1];[_speedPopup selectItemAtIndex:2];
    [_overlapBox setState:NSControlStateValueOff];
    [_sourcePopup selectItemAtIndex:0];
    [self saveSettings:nil];
}
- (void)dismissSettings:(NSModalResponse)result {
    [NSApp endSheet:_panel returnCode:result];
    [_panel orderOut:nil];
    _panel=nil;
}
- (void)cancelSettings:(id)sender {(void)sender;[self dismissSettings:NSModalResponseCancel];}
- (void)saveSettings:(id)sender {
    (void)sender;
    const double speeds[]={0.5,0.75,1.0,1.25,1.5,2.0};
    const BOOL customizable=(_modePopup.indexOfSelectedItem==1);
    [_defaults setInteger:customizable?1:0 forKey:@"mode"];
    /* Do not overwrite remembered Customizable preferences with disabled
       controls when the user saves Faithful mode. */
    if (customizable) {
        [_defaults setBool:_wideBox.state==NSControlStateValueOn forKey:@"wide"];
        [_defaults setObject:NWColorHex(_colorWell.color) forKey:@"color"];
        [_defaults setInteger:_sizePopup.indexOfSelectedItem forKey:@"size"];
        [_defaults setDouble:speeds[MIN(5,MAX(0,(int)_speedPopup.indexOfSelectedItem))] forKey:@"speed"];
        [_defaults setBool:_overlapBox.state==NSControlStateValueOn forKey:@"overlap"];
        [_defaults setBool:_sourcePopup.indexOfSelectedItem==1 forKey:@"demo"];
    }
    [_defaults setBool:_diagnosticsBox.state==NSControlStateValueOn forKey:@"diagnostics"];
    [_defaults synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:NWChangedNotification object:nil];
    [self dismissSettings:NSModalResponseOK];
}
@end
