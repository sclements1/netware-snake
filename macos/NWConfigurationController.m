#import "NWConfigurationController.h"
#include <math.h>

@interface NWConfigurationController ()
- (void)modeChanged:(id)sender;
- (void)controlChanged:(id)sender;
- (void)restoreDefaults:(id)sender;
- (void)saveSettings:(id)sender;
- (void)cancelSettings:(id)sender;
@end

@implementation NWConfigurationController {
    NSUserDefaults *_defaults;
    NWSettings *_draft;
    NSPanel *_panel;
    NSPopUpButton *_modePopup, *_screenPopup, *_speedPopup, *_sizePopup, *_sourcePopup;
    NSPopUpButton *_colorStartPopup, *_cpuPolicyPopup;
    NSColorWell *_colorWell;
    NSButton *_gapsBox, *_eatBox;
    NSTextField *_adaptiveLabel;
    NSTextField *_colorLabel, *_cpuPolicyLabel, *_screenHint, *_cpuCountLabel;
}

static NSTextField *NWLabel(NSView *parent, NSString *text, NSRect frame, BOOL hint) {
    NSTextField *label = [NSTextField wrappingLabelWithString:text];
    label.frame = frame;
    label.font = [NSFont systemFontOfSize:hint ? 11 : 13];
    label.textColor = hint ? NSColor.secondaryLabelColor : NSColor.labelColor;
    [parent addSubview:label];
    return label;
}
static NSColor *NWColorFromHex(NSString *hex) {
    unsigned rgb = 0xaa0000;
    if (hex.length == 7) [[NSScanner scannerWithString:[hex substringFromIndex:1]] scanHexInt:&rgb];
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 255) / 255.0
        green:((rgb >> 8) & 255) / 255.0 blue:(rgb & 255) / 255.0 alpha:1];
}
static NSString *NWHexFromColor(NSColor *color) {
    NSColor *rgb = [color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (!rgb) return @"#AA0000";
    return [NSString stringWithFormat:@"#%02X%02X%02X",
        (unsigned)lround(fmax(0, fmin(1, rgb.redComponent)) * 255),
        (unsigned)lround(fmax(0, fmin(1, rgb.greenComponent)) * 255),
        (unsigned)lround(fmax(0, fmin(1, rgb.blueComponent)) * 255)];
}
static NSColor *NWAttributeColor(NSUInteger attribute) {
    const unsigned char rgb[16][3] = {
        {0,0,0}, {0,0,170}, {0,170,0}, {0,170,170}, {170,0,0}, {170,0,170}, {170,85,0}, {170,170,170},
        {85,85,85}, {85,85,255}, {85,255,85}, {85,255,255}, {255,85,85}, {255,85,255}, {255,255,85}, {255,255,255}};
    attribute %= 16;
    return [NSColor colorWithSRGBRed:rgb[attribute][0] / 255.0
        green:rgb[attribute][1] / 255.0 blue:rgb[attribute][2] / 255.0 alpha:1];
}
- (NSPopUpButton *)popupInView:(NSView *)view frame:(NSRect)frame
                       titles:(NSArray<NSString *> *)titles identifier:(NSString *)identifier {
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:frame pullsDown:NO];
    [popup addItemsWithTitles:titles]; popup.identifier = identifier;
    popup.target = self; popup.action = @selector(controlChanged:); [view addSubview:popup];
    return popup;
}
- (NSButton *)checkboxInView:(NSView *)view frame:(NSRect)frame title:(NSString *)title identifier:(NSString *)identifier {
    NSButton *box = [NSButton checkboxWithTitle:title target:self action:@selector(controlChanged:)];
    box.frame = frame; box.identifier = identifier; [view addSubview:box]; return box;
}
- (NSButton *)buttonInView:(NSView *)view frame:(NSRect)frame title:(NSString *)title action:(SEL)action identifier:(NSString *)identifier {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.frame = frame; button.bezelStyle = NSBezelStyleRounded;
    button.identifier = identifier; [view addSubview:button]; return button;
}
- (instancetype)initWithDefaults:(NSUserDefaults *)defaults {
    self = [super init];
    if (self) {
        _defaults = defaults;
        _panel = [[NSPanel alloc] initWithContentRect:NSMakeRect(0, 0, 660, 714)
            styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
            backing:NSBackingStoreBuffered defer:NO];
        _panel.title = @"NetWare Snake Settings"; _panel.delegate = self; _panel.releasedWhenClosed = NO;
        NSView *content = _panel.contentView;
        NSTextField *heading = NWLabel(content, @"NetWare Snake", NSMakeRect(24, 667, 612, 28), NO);
        heading.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
        NWLabel(content, @"Mode", NSMakeRect(24, 630, 138, 20), NO);
        _modePopup = [self popupInView:content frame:NSMakeRect(176, 626, 460, 27)
            titles:@[@"NetWare 3.12", @"NetWare 4.2", @"Modern"] identifier:@"mode"];
        _modePopup.action = @selector(modeChanged:); _modePopup.menu.autoenablesItems = NO;
        NSMenuItem *modern = [_modePopup itemAtIndex:NWModeModern]; modern.enabled = YES;
        modern.toolTip = @"Planned. Modern behavior has not been defined.";
        NWLabel(content, @"Modern: host CPUs (up to 128), with adaptive core sizing.", NSMakeRect(176, 595, 460, 24), YES);
        NSBox *topRule = [[NSBox alloc] initWithFrame:NSMakeRect(24, 584, 612, 1)];
        topRule.boxType = NSBoxSeparator; [content addSubview:topRule];

        NSView *options = [[NSView alloc] initWithFrame:NSMakeRect(24, 116, 612, 456)];
        [content addSubview:options];
        _colorLabel = NWLabel(options, @"Snake color", NSMakeRect(0, 422, 138, 20), NO);
        _colorWell = [[NSColorWell alloc] initWithFrame:NSMakeRect(152, 413, 82, 32)];
        _colorWell.identifier = @"colorPicker"; _colorWell.target = self; _colorWell.action = @selector(controlChanged:);
        [options addSubview:_colorWell];
        _colorStartPopup = [self popupInView:options frame:NSMakeRect(152, 418, 460, 27) titles:@[] identifier:@"colorStart"];
        for (NSInteger cpu = 0; cpu < 32; ++cpu) {
            NSUInteger attribute = [NWSettings paletteAttributeForCPU:(NSUInteger)cpu colorStart:0];
            NSString *name = [NWSettings paletteColorNameForAttribute:attribute];
            [_colorStartPopup addItemWithTitle:[NSString stringWithFormat:@"CPU %ld — %@", (long)cpu, name]];
            NSMenuItem *item = [_colorStartPopup itemAtIndex:cpu];
            NSColor *color = NWAttributeColor(attribute);
            item.image = [NSImage imageWithSize:NSMakeSize(18, 12) flipped:NO drawingHandler:^BOOL(NSRect rect) {
                [color setFill]; [[NSBezierPath bezierPathWithRoundedRect:NSInsetRect(rect, 1, 1) xRadius:2 yRadius:2] fill];
                return YES;
            }];
        }
        _colorStartPopup.toolTip = @"Choose which historical CPU color starts the continuous 15-color cycle.";
        _gapsBox = [self checkboxInView:options frame:NSMakeRect(0, 378, 612, 24) title:@"Resolve gaps" identifier:@"resolveGaps"];
        _gapsBox.toolTip = @"Keep crossings filled instead of preserving the original erasure gaps.";
        NWLabel(options, @"Screen mode", NSMakeRect(0, 334, 138, 20), NO);
        _screenPopup = [self popupInView:options frame:NSMakeRect(152, 330, 460, 27)
            titles:@[@"4:3 mode", @"Widescreen mode", @"Unified desktop mode"] identifier:@"screenMode"];
        _screenHint = NWLabel(options, @"", NSMakeRect(152, 290, 460, 34), YES);
        _eatBox = [self checkboxInView:options frame:NSMakeRect(0, 252, 612, 24) title:@"Eat the desktop" identifier:@"eatDesktop"];
        NWLabel(options, @"Wallpaper is captured once. Cells visited by the trail turn black.", NSMakeRect(20, 216, 592, 30), YES);
        NWLabel(options, @"Animation speed", NSMakeRect(0, 174, 138, 20), NO);
        _speedPopup = [self popupInView:options frame:NSMakeRect(152, 170, 460, 27)
            titles:@[@"0.5×", @"1×", @"2×"] identifier:@"speed"];
        NWLabel(options, @"Size", NSMakeRect(0, 130, 138, 20), NO);
        _sizePopup = [self popupInView:options frame:NSMakeRect(152, 126, 460, 27)
            titles:@[@"Small", @"Medium", @"Large"] identifier:@"size"];
        NWLabel(options, @"CPU load source", NSMakeRect(0, 86, 138, 20), NO);
        _sourcePopup = [self popupInView:options frame:NSMakeRect(152, 82, 460, 27)
            titles:@[@"Measured", @"Stepped demo"] identifier:@"cpuSource"];
        _cpuPolicyLabel = NWLabel(options, @"CPUs", NSMakeRect(0, 42, 138, 20), NO);
        _cpuPolicyPopup = [self popupInView:options frame:NSMakeRect(152, 38, 460, 27)
            titles:@[@"Detected number up to 31 (Historically accurate)", @"Detected number up to 32", @"Fixed 32"] identifier:@"cpuPolicy"];
        _cpuCountLabel = NWLabel(options, @"", NSMakeRect(152, 0, 460, 32), YES);

        NSBox *bottomRule = [[NSBox alloc] initWithFrame:NSMakeRect(24, 101, 612, 1)];
        bottomRule.boxType = NSBoxSeparator; [content addSubview:bottomRule];
        [self buttonInView:content frame:NSMakeRect(20, 50, 154, 32) title:@"Restore Defaults"
            action:@selector(restoreDefaults:) identifier:@"restoreDefaults"];
        NSButton *cancel = [self buttonInView:content frame:NSMakeRect(436, 50, 92, 32)
            title:@"Cancel" action:@selector(cancelSettings:) identifier:@"cancel"];
        cancel.keyEquivalent = @"\e";
        NSButton *save = [self buttonInView:content frame:NSMakeRect(540, 50, 100, 32)
            title:@"Save" action:@selector(saveSettings:) identifier:@"save"];
        save.keyEquivalent = @"\r";
        NSBundle *bundle = [NSBundle bundleForClass:[NWConfigurationController class]];
        NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"] ?: @"0.7.0";
        NSString *build = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"] ?: @"16";
        NSTextField *footer = NWLabel(content, [NSString stringWithFormat:@"NetWare Snake v%@ · build %@", version, build],
            NSMakeRect(24, 14, 612, 20), YES);
        footer.alignment = NSTextAlignmentCenter; footer.textColor = NSColor.tertiaryLabelColor;
        [self reloadFromDefaults];
    }
    return self;
}
- (NSPanel *)panel { return _panel; }
- (void)reloadFromDefaults { _draft = [[NWSettings settingsWithDefaults:_defaults] copy]; [self populateControls]; }
- (void)populateControls {
    [_modePopup selectItemAtIndex:_draft.mode]; [_screenPopup selectItemAtIndex:_draft.screenMode];
    [_sizePopup selectItemAtIndex:_draft.size];
    [_speedPopup selectItemAtIndex:_draft.speed == 0.5 ? 0 : (_draft.speed == 2 ? 2 : 1)];
    _gapsBox.state = _draft.resolveGaps ? NSControlStateValueOn : NSControlStateValueOff;
    _eatBox.state = _draft.eatDesktop ? NSControlStateValueOn : NSControlStateValueOff;
    _colorWell.color = NWColorFromHex(_draft.colorHex);
    [_colorStartPopup selectItemAtIndex:_draft.colorStart]; [_cpuPolicyPopup selectItemAtIndex:_draft.cpuPolicy];
    BOOL fixed = _draft.mode == NWModeNetWare42 && _draft.cpuPolicy == NWCPUFixed32;
    [_sourcePopup removeAllItems];
    [_sourcePopup addItemsWithTitles:fixed ? @[@"Simulated load"] : @[@"Measured", @"Stepped demo"]];
    _sourcePopup.enabled = !fixed;
    [_sourcePopup selectItemAtIndex:fixed ? 0 : (_draft.demo ? 1 : 0)];
    [self updateVisibleControls];
}
- (void)readControlsIntoDraft {
    _draft.screenMode = (NWScreenMode)_screenPopup.indexOfSelectedItem; _draft.size = _sizePopup.indexOfSelectedItem;
    const double speeds[] = {0.5, 1.0, 2.0}; NSInteger speed = _speedPopup.indexOfSelectedItem;
    _draft.speed = speed >= 0 && speed <= 2 ? speeds[speed] : 1.0;
    if (_sourcePopup.enabled) _draft.demo = _sourcePopup.indexOfSelectedItem == 1;
    _draft.resolveGaps = _gapsBox.state == NSControlStateValueOn; _draft.eatDesktop = _eatBox.state == NSControlStateValueOn;
    if (_draft.mode == NWModeNetWare312) _draft.colorHex = NWHexFromColor(_colorWell.color);
    else { _draft.colorStart = _colorStartPopup.indexOfSelectedItem; _draft.cpuPolicy = (NWCPUPolicy)_cpuPolicyPopup.indexOfSelectedItem; }
}
- (void)updateVisibleControls {
    BOOL smp = _draft.mode != NWModeNetWare312;
    BOOL modern = _draft.mode == NWModeModern;
    _screenPopup.enabled=!modern;
    if(!_adaptiveLabel)_adaptiveLabel=NWLabel(_sizePopup.superview,@"Adaptive — E: Small · P: Medium · S: Large",_sizePopup.frame,NO);
    _adaptiveLabel.hidden=!modern;
    _sizePopup.hidden=modern;
    _cpuCountLabel.frame=modern?NSMakeRect(152,22,460,50):NSMakeRect(152,0,460,32);
    _sizePopup.enabled=!modern;
    _colorLabel.stringValue = smp ? @"CPU 0 color" : @"Snake color";
    if (smp) [_colorWell deactivate];
    _colorWell.hidden = smp; _colorStartPopup.hidden = !smp;
    _cpuPolicyPopup.hidden = !smp || modern; _cpuPolicyLabel.hidden = !smp; _cpuCountLabel.hidden = !smp;
    NSArray<NSString *> *hints = @[@"A centered 4:3 console on each screen.", @"The console fills each screen's width.",
        @"One shared desktop spans all macOS screens."];
    _screenHint.stringValue = hints[_draft.screenMode];
    NSUInteger host = MAX((NSUInteger)1, NSProcessInfo.processInfo.processorCount);
    if(modern) _cpuCountLabel.stringValue=[NSString stringWithFormat:@"%lu host CPUs · %lu snakes · Adaptive: E small, P medium, S large. Unknown: medium.",(unsigned long)host,(unsigned long)MIN(host,(NSUInteger)128)];
    else if (_draft.cpuPolicy == NWCPUFixed32) _cpuCountLabel.stringValue = [NSString stringWithFormat:
        @"32 simulated CPUs. Host has %lu logical CPUs.", (unsigned long)host];
    else {
        NSUInteger used = MIN(host, _draft.cpuPolicy == NWCPUDetected32 ? (NSUInteger)32 : (NSUInteger)31);
        _cpuCountLabel.stringValue = [NSString stringWithFormat:@"Uses %lu of %lu host logical CPUs. One snake per CPU.",
            (unsigned long)used, (unsigned long)host];
    }
}
- (void)modeChanged:(id)sender {
    (void)sender; [self readControlsIntoDraft];
    NSInteger mode = _modePopup.indexOfSelectedItem;
    if (mode == NWModeNetWare312 || mode == NWModeNetWare42 || mode == NWModeModern) _draft.mode = (NWMode)mode;
    [self populateControls];
}
- (void)controlChanged:(id)sender { (void)sender; [self readControlsIntoDraft]; [self populateControls]; }
- (void)restoreDefaults:(id)sender { (void)sender; [_draft resetCurrentModeToDefaults]; [self populateControls]; }
- (void)dismissWithResponse:(NSModalResponse)response {
    [_colorWell deactivate];
    NSWindow *parent = _panel.sheetParent; if (parent) [parent endSheet:_panel returnCode:response]; [_panel orderOut:nil];
}
- (void)saveSettings:(id)sender {
    (void)sender; [self readControlsIntoDraft]; [_draft saveToDefaults:_defaults];
    [[NSNotificationCenter defaultCenter] postNotificationName:NWSettingsDidChangeNotification object:nil];
    [self dismissWithResponse:NSModalResponseOK];
}
- (void)cancelSettings:(id)sender { (void)sender; [self dismissWithResponse:NSModalResponseCancel]; }
- (BOOL)windowShouldClose:(NSWindow *)sender { (void)sender; [self cancelSettings:nil]; return NO; }
@end
