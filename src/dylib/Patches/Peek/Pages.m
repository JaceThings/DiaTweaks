#import "Patches/Peek/Peek.h"
#import <objc/message.h>

// A Peek's page is made by Peek, in the same space as the page it came from, so it has the same sign-ins. Like Arc's,
// it isn't a tab until it's expanded or split: then Dia is handed the live page the way it's handed the page a link
// opens, so nothing reloads. Closing the Peek discards it. Until then Dia doesn't manage the page, so popups and
// permission prompts from inside a Peek wait until it's expanded.
static NSMapTable *DPPeekFactories;  // Each page -> the browser context or browser that made it.
static __weak id DPPeekLastFactory;  // The context or browser that most recently made a page: the active profile.
static NSMapTable<NSWindow *, id> *DPPeekBrowsers;  // Each window -> the ArcBrowser Dia gave it.

static id DPContext_create(id self, SEL _cmd, id configuration) {
    id page = DPCallOriginal(DPContext_create, self, configuration);
    if (page) { [DPPeekFactories setObject:self forKey:page]; DPPeekLastFactory = self; }
    return page;
}

static id DPBrowser_create(id self, SEL _cmd, id configuration) {
    id page = DPCallOriginal(DPBrowser_create, self, configuration);
    if (page) { [DPPeekFactories setObject:self forKey:page]; DPPeekLastFactory = self; }
    return page;
}

// Dia gives each window its ArcBrowser, restored windows included, before any page is made in it. That browser makes
// pages in the window's profile, so a shift-click can peek right after Dia starts.
static void DPBrowser_setWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPBrowser_setWindow, self, window);
    if (window) [DPPeekBrowsers setObject:self forKey:window];
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

// The browser context or browser that can make a peek's page in the same space as `source`. A page Peek caught at
// creation is in the factory map. Dia makes older and restored tabs without going through the hooked createWebContents,
// and their page (a Swift object) exposes no pointer to its context, so those use the window's own browser, or else
// the context that last made a page.
static id DPPeekContextForSource(id source, NSWindow *window) {
    if (!source) return nil;
    return [DPPeekFactories objectForKey:source] ?: (window ? [DPPeekBrowsers objectForKey:window] : nil) ?: DPPeekLastFactory;
}

BOOL DPPeekCanOpen(id source) { return DPPeekContextForSource(source, NSApp.keyWindow) != nil; }

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

// The box of the link under `origin` on screen, asked of the page it's on, so the card can grow out of exactly that. A
// link that wraps gives the line that was clicked. Anything the page can't answer, such as a link in a frame, gets a
// line-high box around the click.
static void DPPeekFindLink(NSWindow *window, id source, NSPoint origin, void (^found)(NSRect link)) {
    NSRect fallback = NSMakeRect(origin.x - 40, origin.y - 10, 80, 20);
    NSView *web = DPFindView(window.contentView, ^BOOL(NSView *view) {
        return DPIsKind(view, "WebContentsHostView") && !view.isHiddenOrHasHiddenAncestor
            && NSPointInRect([view convertPoint:[window convertPointFromScreen:origin] fromView:nil], view.bounds);
    });
    if (!web || ![source respondsToSelector:@selector(executeJavascript:completion:)]) return found(fallback);
    NSPoint point = [web convertPoint:[window convertPointFromScreen:origin] fromView:nil];
    CGFloat top = web.isFlipped ? point.y : NSHeight(web.bounds) - point.y;
    NSString *script = [NSString stringWithFormat:@"(function(x, y, w) {"
        "var k = innerWidth / w, e = document.elementFromPoint(x * k, y * k); if (!e) return '';"
        "var a = e.closest('a') || e, r = a.getBoundingClientRect();"
        "for (var b of a.getClientRects()) if (x * k >= b.left && x * k <= b.right && y * k >= b.top && y * k <= b.bottom) r = b;"
        "return [r.left / k - x, r.top / k - y, r.width / k, r.height / k].join(',');"
        "})(%f, %f, %f)", point.x, top, NSWidth(web.bounds)];
    __block BOOL done = NO;
    void (^finish)(NSRect) = ^(NSRect link) {
        if (done) return;
        done = YES;
        found(link);
    };
    // A page that's busy can't hold the peek up for long.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ finish(fallback); });
    void (^answer)(NSString *, BOOL) = ^(NSString *result, BOOL ok) {
        // The answer comes back as JSON, so a string arrives in quotes.
        NSString *box = [result stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\""]];
        NSArray<NSString *> *parts = [box componentsSeparatedByString:@","];
        if (!ok || parts.count != 4 || parts[2].doubleValue < 1 || parts[3].doubleValue < 1) return dispatch_async(dispatch_get_main_queue(), ^{ finish(fallback); });
        // The box comes back relative to the click, in points, so it lands where the click did on screen.
        CGFloat dx = parts[0].doubleValue, dy = parts[1].doubleValue, w = parts[2].doubleValue, h = parts[3].doubleValue;
        NSRect link = NSMakeRect(origin.x + dx, origin.y - dy - h, w, h);
        dispatch_async(dispatch_get_main_queue(), ^{ finish(link); });
    };
    ((void (*)(id, SEL, NSString *, id))objc_msgSend)(source, @selector(executeJavascript:completion:), script, answer);
}

// The page is set up for drawing, attached to a card, then loaded. If no card can show it, it opens as a tab.
static void DPPeekOpenFrom(NSWindow *window, NSURL *url, NSRect link, id delegate, id source) {
    id factory = DPPeekContextForSource(source, window);
    Class configuration = objc_getClass(DPDiaWebContentsConfiguration);
    if (!window || !url || !factory || !configuration || DPPeekCardIn(window)) return;
    id page = ((id (*)(id, SEL, id))objc_msgSend)(factory, @selector(createWebContents:), [configuration new]);
    if (!page) return;
    if ([page respondsToSelector:@selector(bootstrapRendering)]) [page performSelector:@selector(bootstrapRendering)];
    DPPeekCard *peek = DPPeekShowCard(window, page, link);
    if ([page respondsToSelector:@selector(bootstrapRenderingComplete)]) [page performSelector:@selector(bootstrapRenderingComplete)];
    DPPeekLoad(page, url);
    if (!peek) {
        DPPeekGive(page, delegate, source, url, 2);  // NewForegroundTab
        return;
    }
    peek.sourceDelegate = delegate;
    peek.source = source;
    DPPeekShowTabBadge(peek, source, page);
}

void DPPeekOpen(NSWindow *window, NSURL *url, NSPoint origin, id delegate, id source) {
    DPPeekFindLink(window, source, origin, ^(NSRect link) { DPPeekOpenFrom(window, url, link, delegate, source); });
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
    DPPeekBrowsers = [NSMapTable weakToWeakObjectsMapTable];
    DPHook(DPDiaBrowser, @selector(setWindow:), (IMP)DPBrowser_setWindow);
    DPHook(DPDiaBrowserContext, @selector(createWebContents:), (IMP)DPContext_create);
    DPHook(DPDiaBrowser, @selector(createWebContents:), (IMP)DPBrowser_create);
    DPHook(DPDiaWebContents, @selector(attachToPaneHostView:), (IMP)DPPage_attach);
    // A Peek can't outlast the window it's in.
    [NSNotificationCenter.defaultCenter addObserverForName:NSWindowWillCloseNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        [DPPeekCardIn(note.object) close:0];
    }];
}
