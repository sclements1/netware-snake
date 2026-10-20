/* Native standalone smoke-test host for the identical ScreenSaverView used
   in the plug-in. Useful when recent macOS versions mismanage .saver previews. */
#import <Cocoa/Cocoa.h>
#import "NetWareSnakeView.h"
@interface NWPreviewDelegate : NSObject <NSApplicationDelegate, NSWindowDelegate>
@property (strong) NSWindow *window;
@property (strong) NetWareSnakeView *snake;
- (void)openPreferences:(id)sender;
@end
@implementation NWPreviewDelegate
- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    (void)notification;
    NSRect rect=NSMakeRect(0,0,1180,720);
    self.window=[[NSWindow alloc] initWithContentRect:rect
       styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskClosable|
                 NSWindowStyleMaskMiniaturizable|NSWindowStyleMaskResizable
       backing:NSBackingStoreBuffered defer:NO];
    self.window.title=@"NetWare Snake — Native Preview";
    self.window.delegate=self;
    self.snake=[[NetWareSnakeView alloc] initWithFrame:NSMakeRect(0,0,rect.size.width,rect.size.height) isPreview:NO];
    self.snake.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
    self.window.contentView=self.snake;
    [self.window center];[self.window makeKeyAndOrderFront:nil];
    [self.snake startAnimation];
    [NSApp activateIgnoringOtherApps:YES];
}
- (void)windowWillClose:(NSNotification *)notification {
    (void)notification;[self.snake stopAnimation];[NSApp terminate:nil];
}
- (void)openPreferences:(id)sender {
    (void)sender;
    NSPanel *sheet=(NSPanel *)[self.snake configureSheet];
    [self.window beginSheet:sheet completionHandler:nil];
}
@end
int main(int argc,char **argv) {
    (void)argc;(void)argv;
    @autoreleasepool {
        NSApplication *app=[NSApplication sharedApplication];
        [app setActivationPolicy:NSApplicationActivationPolicyRegular];
        static NWPreviewDelegate *delegate;
        delegate=[NWPreviewDelegate new];app.delegate=delegate;
        NSMenu *bar=[NSMenu new];[app setMainMenu:bar];
        NSMenuItem *root=[NSMenuItem new];[bar addItem:root];
        NSMenu *menu=[NSMenu new];root.submenu=menu;
        NSMenuItem *prefs=[menu addItemWithTitle:@"Settings…" action:@selector(openPreferences:) keyEquivalent:@","];
        prefs.target=delegate;
        [menu addItem:[NSMenuItem separatorItem]];
        [menu addItemWithTitle:@"Quit NetWare Snake" action:@selector(terminate:) keyEquivalent:@"q"];
        [app run];
    }
    return 0;
}
