#import "Patches/Peek/Peek.h"
#import <objc/message.h>

// A Peek's page is made by Peek, in the same space as the page it came from, so it has the same sign-ins. Like Arc's,
// it isn't a tab until it's expanded or split: then Dia is handed the live page the way it's handed the page a link
// opens, so nothing reloads. Closing the Peek discards it. Until then Dia doesn't manage the page, so popups and
// permission prompts from inside a Peek wait until it's expanded.
static NSMapTable *DPPeekFactories;  // Each page -> the browser context or browser that made it.

static id DPContext_create(id self, SEL _cmd, id configuration) {
    id page = DPCallOriginal(DPContext_create, self, configuration);
    if (page) [DPPeekFactories setObject:self forKey:page];
    return page;
}

static id DPBrowser_create(id self, SEL _cmd, id configuration) {
    id page = DPCallOriginal(DPBrowser_create, self, configuration);
    if (page) [DPPeekFactories setObject:self forKey:page];
    return page;
}

// Dia attaching a Peek's page somewhere else, such as when it's selected, means the card has to let go of it, or
// Dia's own pane stays white.
static void DPPage_attach(id self, SEL _cmd, NSView *host) {
    for (NSWindow *window in NSApp.windows) {
        DPPeekCard *peek = DPPeekCardIn(window);
        if (peek.page == self && host != peek.host) [peek handOver];
    }
    DPCallOriginal(DPPage_attach, self, host);
}

BOOL DPPeekCanOpen(id source) { return source && [DPPeekFactories objectForKey:source]; }

BOOL DPPeekShows(id page) {
    if (!page) return NO;
    for (NSWindow *window in NSApp.windows) if (DPPeekCardIn(window).page == page) return YES;
    return NO;
}

void DPPeekLoad(id page, NSURL *url) {
    id navigation = [(NSObject *)page valueForKey:@"navigationController"];
    SEL load = @selector(load:initiatorOrigin:);
    if (url && [navigation respondsToSelector:load]) ((id (*)(id, SEL, NSURL *, NSURL *))objc_msgSend)(navigation, load, url, nil);
}

// Hands `page` to Dia as the page a link on `source` opened, with an ArcWebContentsNavigationDisposition.
static BOOL DPPeekGive(id page, id delegate, id source, NSURL *url, NSInteger disposition) {
    SEL adopt = @selector(webContents:didCreateNewWebContent:targetURL:disposition:);
    if (!page || !source || ![url isKindOfClass:NSURL.class] || ![delegate respondsToSelector:adopt]) return NO;
    ((void (*)(id, SEL, id, id, NSURL *, NSInteger))objc_msgSend)(delegate, adopt, source, page, url, disposition);
    return YES;
}

// The page is set up for drawing, attached to a card, then loaded. If no card can show it, it opens as a tab.
void DPPeekOpen(NSWindow *window, NSURL *url, NSPoint origin, id delegate, id source) {
    id factory = source ? [DPPeekFactories objectForKey:source] : nil;
    Class configuration = objc_getClass(DPDiaWebContentsConfiguration);
    if (!window || !url || !factory || !configuration || DPPeekCardIn(window)) return;
    id page = ((id (*)(id, SEL, id))objc_msgSend)(factory, @selector(createWebContents:), [configuration new]);
    if (!page) return;
    if ([page respondsToSelector:@selector(bootstrapRendering)]) [page performSelector:@selector(bootstrapRendering)];
    DPPeekCard *peek = DPPeekShowCard(window, page, origin);
    if ([page respondsToSelector:@selector(bootstrapRenderingComplete)]) [page performSelector:@selector(bootstrapRenderingComplete)];
    DPPeekLoad(page, url);
    if (!peek) {
        DPPeekGive(page, delegate, source, url, 2);  // NewForegroundTab
        return;
    }
    peek.sourceDelegate = delegate;
    peek.source = source;
}

@implementation DPPeekCard (Handoff)

// 0 discards the page, 1 hands it to Dia as a new tab, 2 as a split view pane. It carries on exactly where it was.
- (void)finish:(NSInteger)exit {
    NSWindow *window = self.window;
    NSObject *page = (NSObject *)self.page;
    [self.page detachFromPaneHostView:self.host];
    [self removeFromSuperview];
    [window makeKeyWindow];
    NSInteger disposition = exit == 2 ? 9 : 2;  // SplitView, NewForegroundTab
    if (exit == 0 || !DPPeekGive(page, self.sourceDelegate, self.source, [page valueForKey:@"url"], disposition))
        [page performSelector:@selector(close)];
}

@end

void DPPeekInstallPages(void) {
    DPPeekFactories = [NSMapTable weakToWeakObjectsMapTable];
    DPHook(DPDiaBrowserContext, @selector(createWebContents:), (IMP)DPContext_create);
    DPHook(DPDiaBrowser, @selector(createWebContents:), (IMP)DPBrowser_create);
    DPHook(DPDiaWebContents, @selector(attachToPaneHostView:), (IMP)DPPage_attach);
    // A Peek can't outlast the window it's in.
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [DPPeekCardIn(note.object) close:0];
    }];
}
