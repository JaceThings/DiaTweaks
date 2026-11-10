#import "DevMode.h"
#import <objc/message.h>

static const NSInteger DPVisible = 2;
static NSHashTable *DPPages;

static void DPTrack(id page) {
    [DPPages addObject:page];
    dispatch_async(dispatch_get_main_queue(), ^{ DPUpdateToolbars(); });
}

static void DPPage_setVisibility(id self, SEL _cmd, NSInteger visibility) {
    DPCallOriginal(DPPage_setVisibility, self, visibility);
    DPTrack(self);
}

static void DPPage_setUrl(id self, SEL _cmd, id url) {
    DPCallOriginal(DPPage_setUrl, self, url);
    DPTrack(self);
}

static void DPPage_attach(id self, SEL _cmd, id host) {
    DPCallOriginal(DPPage_attach, self, host);
    DPTrack(self);
}

void DPInstallPages(void) {
    DPPages = [NSHashTable weakObjectsHashTable];
    DPHook(DPDiaWebContents, @selector(setVisibility:), (IMP)DPPage_setVisibility);
    DPHook(DPDiaWebContents, @selector(setUrl:), (IMP)DPPage_setUrl);
    DPHook(DPDiaWebContents, @selector(attachToPaneHostView:), (IMP)DPPage_attach);
}

static NSInteger DPVisibilityOf(id page) { return ((NSInteger (*)(id, SEL))objc_msgSend)(page, @selector(visibility)); }

static NSView *DPViewOf(id page) {
    return [page respondsToSelector:@selector(nativeView)] ? [page performSelector:@selector(nativeView)] : nil;
}

static NSURL *DPURLOf(id page) {
    id url = [page respondsToSelector:@selector(url)] ? [page performSelector:@selector(url)] : nil;
    return [url isKindOfClass:NSString.class] ? [NSURL URLWithString:url] : [url isKindOfClass:NSURL.class] ? url : nil;
}

static BOOL DPIsDevTools(id page) { return [DPURLOf(page).scheme isEqualToString:@"devtools"]; }

id DPFrontPage(void) {
    id found = nil;
    for (id page in DPPages.allObjects) {
        if (DPViewOf(page).window != NSApp.keyWindow || DPVisibilityOf(page) != DPVisible || DPIsDevTools(page)) continue;
        if (!found || ((BOOL (*)(id, SEL))objc_msgSend)(page, @selector(hasFocus))) found = page;
    }
    return found;
}

id DPPageIn(NSView *pane) {
    for (id page in DPPages.allObjects)
        if ([DPViewOf(page) isDescendantOf:pane] && !DPIsDevTools(page)) return page;
    return nil;
}

NSView *DPPaneAbove(NSView *view) {
    while (view && !DPIsKind(view, DPDiaContentPane)) view = view.superview;
    return view;
}

NSView *DPPaneOf(id page) { return DPPaneAbove(DPViewOf(page)); }

NSString *DPHostOf(id page) {
    NSURL *url = DPURLOf(page);
    NSString *scheme = [url scheme].lowercaseString;
    if (![scheme isEqualToString:@"http"] && ![scheme isEqualToString:@"https"]) return nil;
    return [url host].lowercaseString;
}
