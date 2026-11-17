/* Native preview uses the identical ScreenSaverView as the plug-in. */
#import <Cocoa/Cocoa.h>
#import "NetWareSnakeView.h"
@interface NWPreviewDelegate : NSObject <NSApplicationDelegate,NSWindowDelegate>
@property(strong) NSWindow *window;
@property(strong) NetWareSnakeView *snake;
@property(strong) NSMutableArray<NSWindow *> *displayWindows;
@property(strong) NSTimer *timer;
@property(strong) NSUserDefaults *previewDefaults;
- (void)openPreferences:(id)sender;
- (void)toggleDisplays:(id)sender;
- (void)returnToWindow:(id)sender;
@end
@implementation NWPreviewDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSArray *arguments=NSProcessInfo.processInfo.arguments;
    NSUInteger isolated=[arguments indexOfObject:@"--isolated-settings"];
    if(isolated!=NSNotFound && isolated+1<arguments.count)
        self.previewDefaults=[[NSUserDefaults alloc] initWithSuiteName:arguments[isolated+1]];
    NSRect rect=NSMakeRect(0,0,1180,720);
    self.window=[[NSWindow alloc] initWithContentRect:rect styleMask:NSWindowStyleMaskTitled|
        NSWindowStyleMaskClosable|NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
        backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"NetWare Snake — Preview";self.window.delegate=self;
    self.snake=[[NetWareSnakeView alloc] initWithFrame:NSMakeRect(0,0,rect.size.width,rect.size.height)
        isPreview:NO defaults:self.previewDefaults];
    self.snake.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;self.window.contentView=self.snake;
    [self.window center];[self.window makeKeyAndOrderFront:nil];[self.snake startAnimation];
    self.displayWindows=[NSMutableArray new];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screensChanged:)
        name:NSApplicationDidChangeScreenParametersNotification object:nil];
    self.timer=[NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(tick:)
        userInfo:nil repeats:YES];
    [NSApp activateIgnoringOtherApps:YES];
    if([arguments containsObject:@"--settings"])[self openPreferences:nil];
}
- (void)tick:(NSTimer *)timer {
    (void)timer;
    if(self.displayWindows.count) {
        for(NSWindow *window in self.displayWindows)[(NetWareSnakeView *)window.contentView animateOneFrame];
    } else [self.snake animateOneFrame];
}
- (void)windowWillClose:(NSNotification *)notification {
    if(notification.object==self.window) {
        [self.timer invalidate];[self.snake stopAnimation];
        for(NSWindow *window in self.displayWindows)[(NetWareSnakeView *)window.contentView stopAnimation];
        [NSApp terminate:nil];
    }
}
- (void)openPreferences:(id)sender {
    (void)sender;
    if(self.displayWindows.count)[self toggleDisplays:nil];
    if(self.window.attachedSheet)return;
    [self.window beginSheet:[self.snake configureSheet] completionHandler:nil];
}
- (void)returnToWindow:(id)sender {
    if(self.displayWindows.count)[self toggleDisplays:sender];
}
- (void)screensChanged:(NSNotification *)notification {
    (void)notification;
    if(!self.displayWindows.count)return;
    [self toggleDisplays:nil];
    if(NSScreen.screens.count)[self toggleDisplays:nil];
}
- (void)toggleDisplays:(id)sender {
    (void)sender;
    if(self.window.attachedSheet)return;
    if(self.displayWindows.count) {
        for(NSWindow *window in self.displayWindows) {
            [(NetWareSnakeView *)window.contentView stopAnimation];[window orderOut:nil];
        }
        [self.displayWindows removeAllObjects];
        [self.window makeKeyAndOrderFront:nil];[self.snake startAnimation];return;
    }
    [self.snake stopAnimation];[self.window orderOut:nil];
    for(NSScreen *screen in NSScreen.screens) {
        // With an explicit screen, AppKit expects an origin relative to that screen.
        NSRect displayRect=NSMakeRect(0,0,screen.frame.size.width,screen.frame.size.height);
        NSWindow *window=[[NSWindow alloc] initWithContentRect:displayRect styleMask:NSWindowStyleMaskBorderless
            backing:NSBackingStoreBuffered defer:NO screen:screen];
        window.releasedWhenClosed=NO;
        NetWareSnakeView *view=[[NetWareSnakeView alloc] initWithFrame:NSMakeRect(0,0,screen.frame.size.width,screen.frame.size.height)
            isPreview:NO defaults:self.previewDefaults];
        window.contentView=view;[self.displayWindows addObject:window];
        [window orderFront:nil];[view startAnimation];
    }
}
@end
int main(int argc,char **argv) {
    (void)argc;(void)argv;
    @autoreleasepool {
        NSApplication *app=NSApplication.sharedApplication;
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        static NWPreviewDelegate *delegate;delegate=[NWPreviewDelegate new];app.delegate=delegate;
        NSMenu *bar=[NSMenu new];app.mainMenu=bar;NSMenuItem *root=[NSMenuItem new];[bar addItem:root];
        NSMenu *menu=[NSMenu new];root.submenu=menu;
        NSMenuItem *prefs=[menu addItemWithTitle:@"Settings…" action:@selector(openPreferences:) keyEquivalent:@","];
        prefs.target=delegate;
        NSMenuItem *displays=[menu addItemWithTitle:@"Preview All Displays / Return" action:@selector(toggleDisplays:) keyEquivalent:@"f"];
        displays.target=delegate;displays.keyEquivalentModifierMask=NSEventModifierFlagCommand|NSEventModifierFlagShift;
        NSMenuItem *escape=[menu addItemWithTitle:@"Return to Window" action:@selector(returnToWindow:) keyEquivalent:@"\e"];
        escape.target=delegate;escape.keyEquivalentModifierMask=0;
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Quit NetWare Snake" action:@selector(terminate:) keyEquivalent:@"q"];
        [app run];
    }
    return 0;
}
