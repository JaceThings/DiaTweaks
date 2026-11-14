#import "StdPatch/StdPatch.h"
#import "Title.h"
#import <objc/message.h>

extern DPPatch DPFeishuTabTitles;

// ArcWebContents exposes Chromium's title to Dia. This getter changes the
// returned native string while Chromium and the document retain their title.
static NSString *DPContents_title(id self, SEL _cmd) {
    NSString *title = DPCallOriginal(DPContents_title, self);
    if (!DPFeishuTabTitles.on || !title.length) return title;
    NSURL *url = ((NSURL *(*)(id, SEL))objc_msgSend)(self, @selector(url));
    return DPFeishuDisplayTitle(title, url);
}

static void DPInstallFeishuTabTitles(void) {
    DPHook(DPDiaWebContents, @selector(title), (IMP)DPContents_title);
}

DP_PATCH(DPFeishuTabTitles) {
    .key = @"feishuTabTitles",
    .order = 205,
    .title = @"Feishu Document Titles",
    .detail = @"Show Feishu document names when invisible title prefixes make tabs show a domain. Filters the native title string as Dia reads it.",
    .hint = @"Reload open Feishu tabs after changing this setting.",
    .symbol = @"textformat",
    .tint = @"systemPinkColor",
    .section = @"Tabs",
    .classes = DPClasses(DPDiaWebContents),
    .install = DPInstallFeishuTabTitles,
};
