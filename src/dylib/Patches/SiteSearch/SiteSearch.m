#import "SiteSearch.h"

static char DPSiteKey;

static __weak NSTextView *DPSearching;  // The field with a site chosen, if any.

static DPSite *DPSiteOf(NSTextView *text) { return DPGet(text, &DPSiteKey); }

static void DPSetSite(NSTextView *text, DPSite *site) {
    DPSet(text, &DPSiteKey, site);
    DPShowChip(text, site);
    DPShowReturnTarget(text, site);
    if (site) DPSearching = text;
    else if (DPSearching == text) DPSearching = nil;
}

static void DPReplaceText(NSTextView *text, NSString *string) {
    [text setSelectedRange:NSMakeRange(0, text.string.length)];
    [text insertText:string replacementRange:NSMakeRange(0, text.string.length)];
}

#pragma mark Return

#define DPDiaSuggestionsView "_TtC15BoostCommandBar15SuggestionsView"

static NSTableView *DPSuggestionsOf(NSTextView *text) {
    return (NSTableView *)DPFindView(text.window.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTableView.class] && DPIsKind(((NSTableView *)view).delegate, DPDiaSuggestionsView);
    });
}

static NSString *DPRowText(NSTableView *table, NSInteger row) {
    if (row < 0 || row >= table.numberOfRows) return @"";
    NSMutableArray *parts = [NSMutableArray new];
    DPFindView([table rowViewAtRow:row makeIfNecessary:NO], ^BOOL(NSView *view) {
        if ([view isKindOfClass:NSTextField.class]) [parts addObject:((NSTextField *)view).stringValue];
        return NO;
    });
    return [parts componentsJoinedByString:@" | "];
}

// Return opens the suggestion Dia picked, which lags what's in the field. So it waits, up to `tries` times 20ms, until
// the pick is the address put there.
static void DPReturnWhenTyped(NSTextView *text, NSURL *url, int tries) {
    NSTableView *table = DPSuggestionsOf(text);
    NSString *picked = DPRowText(table, table.selectedRow), *bare = [url.absoluteString substringFromIndex:@"https://".length];
    BOOL ready = [picked containsString:bare] || [picked containsString:[bare stringByRemovingPercentEncoding] ?: bare];
    if (!ready && tries > 0 && text.window)
        return (void)dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{ DPReturnWhenTyped(text, url, tries - 1); });
    if (text.window) [text doCommandBySelector:@selector(insertNewline:)];
}

#pragma mark Keys

static BOOL DPInput_command(NSView *self, SEL _cmd, NSTextView *text, SEL command) {
    if (!DPSiteSearch.on || text.hasMarkedText) return DPCallOriginal(DPInput_command, self, text, command);
    DPSite *site = DPSiteOf(text);
    if (!site) {
        if (command != @selector(insertTab:)) return DPCallOriginal(DPInput_command, self, text, command);
        site = DPSiteFor(text.string, text.window);
        if (!site) return DPCallOriginal(DPInput_command, self, text, command);
        DPSetSite(text, site);  // First, while the suggestions still show the site's icon.
        DPReplaceText(text, @"");
        return YES;
    }
    if (command == @selector(insertNewline:)) {
        NSString *query = [text.string stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSURL *url = DPSiteSearchURL(site, query);
        DPSetSite(text, nil);
        DPReplaceText(text, url.absoluteString);
        DPReturnWhenTyped(text, url, 50);
        return YES;
    }
    if (command == @selector(deleteBackward:) && !text.string.length) {
        DPSetSite(text, nil);
        DPReplaceText(text, site.host);
        return YES;
    }
    if (command == @selector(insertTab:)) return YES;
    if (command == @selector(cancelOperation:)) DPSetSite(text, nil);
    return DPCallOriginal(DPInput_command, self, text, command);
}

// Words for a site aren't an address, so Dia shouldn't complete them into one: "g" isn't google.com on Amazon.
static BOOL DPBrowser_autocomplete(id self, SEL _cmd, NSString *text, int cursor, BOOL prevent, BOOL fresh, id keyword, id *error, void (^completion)(id, BOOL)) {
    NSTextView *field = DPSearching;
    if (!DPSiteSearch.on || !DPSiteOf(field) || !completion) return DPCallOriginal(DPBrowser_autocomplete, self, text, cursor, prevent, fresh, keyword, error, completion);
    // Dia names the Return button again with each update, so the site's name goes back after it.
    return DPCallOriginal(DPBrowser_autocomplete, self, text, cursor, YES, fresh, keyword, error, ^(id result, BOOL done) {
        completion(result, done);
        dispatch_async(dispatch_get_main_queue(), ^{ DPShowReturnTarget(field, DPSiteOf(field)); });
    });
}

// The bar's field is used again the next time it opens, so a site left from before goes when it closes.
static void DPText_viewDidMoveToWindow(NSTextView *self, SEL _cmd) {
    DPCallOriginal(DPText_viewDidMoveToWindow, self);
    if (DPSiteOf(self)) DPSetSite(self, nil);
}

static void DPInstallSiteSearch(void) {
    DPHook(DPDiaCommandBarText, @selector(textView:doCommandBySelector:), (IMP)DPInput_command);
    DPHookClass(NSTextView.class, @selector(viewDidMoveToWindow), (IMP)DPText_viewDidMoveToWindow);
    DPHook(DPDiaBrowser, @selector(autocomplete:cursorPosition:preventInlineAutocomplete:startFresh:keyword:error:completion:), (IMP)DPBrowser_autocomplete);
}

static void DPApplySiteSearch(DPPatch *patch) {
    if (patch->on) return;
    for (NSView *view in DPFindViews("NSTextView"))
        if (DPSiteOf((NSTextView *)view)) DPSetSite((NSTextView *)view, nil);
}

// Nothing shows until Tab is pressed, so this checks what it relies on: the bar's field still hands its keys over.
static NSString *DPVerifySiteSearch(DPPatch *patch) {
    Class input = objc_getClass(DPDiaCommandBarText);
    return patch->on && ![input instancesRespondToSelector:@selector(textView:doCommandBySelector:)] ? @"the command bar's field doesn't take keys" : nil;
}

DP_PATCH(DPSiteSearch) {
    .key = @"siteSearch",
    .order = 93,
    .title = @"Search Sites with Tab",
    .detail = @"Type a site such as amazon.com in the command bar, press Tab, then type what to search for on it and press Return. Works with popular sites and any site whose search box you've used.",
    .symbol = @"magnifyingglass.circle.fill magnifyingglass",
    .tint = @"systemOrangeColor",
    .section = @"Command Bar",
    .classes = DPClasses(DPDiaCommandBarText, DPDiaBrowser),
    .install = DPInstallSiteSearch,
    .apply = DPApplySiteSearch,
    .verify = DPVerifySiteSearch,
};
