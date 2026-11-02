#import "CommandBar.h"

static NSArray *DPScriptedWindows(void) {
    @try { return [NSApp valueForKey:@"appleScriptWindows"]; }
    @catch (__unused NSException *e) { return nil; }
}

static id DPScriptedWindow(NSWindow *window) {
    @try {
        for (id scripted in DPScriptedWindows())
            if ([[scripted valueForKey:@"windowId"] isEqual:window.identifier]) return scripted;
    } @catch (__unused NSException *e) {}
    return nil;
}

static id DPActiveTab(NSWindow *window) {
    @try { return [DPScriptedWindow(window) valueForKey:@"activeTab"]; }
    @catch (__unused NSException *e) { return nil; }
}

static NSString *DPSpaceOf(id scripted) {
    id name = [[scripted valueForKey:@"activeProfile"] valueForKey:@"name"];
    return [name isKindOfClass:NSString.class] ? name : nil;
}

NSString *DPBarSpaceOfWindow(NSWindow *window) {
    @try { return DPSpaceOf(DPScriptedWindow(window)); }
    @catch (__unused NSException *e) { return nil; }
}

BOOL DPBarCanScript(NSWindow *window) { return DPActiveTab(window) != nil; }

BOOL DPBarCanListSpaces(NSWindow *window) {
    @try { return [[DPScriptedWindow(window) valueForKey:@"appleScriptProfiles"] count] > 0; }
    @catch (__unused NSException *e) { return NO; }
}

NSString *DPBarURLOfWindow(NSWindow *window) {
    @try {
        id url = [DPActiveTab(window) valueForKey:@"URL"];
        return [url isKindOfClass:NSString.class] ? url : nil;
    } @catch (__unused NSException *e) { return nil; }
}

void DPBarNavigate(NSWindow *window, NSString *url) {
    id tab = DPActiveTab(window);
    if (!url.length || !tab) return;
    @try { [tab setValue:url forKey:@"URL"]; }
    @catch (NSException *e) { NSLog(@"[DiaPatches] command bar couldn't navigate: %@", e); }
}

static void DPRunScript(NSString *source) {
    NSDictionary *error = nil;
    [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
    if (error) NSLog(@"[DiaPatches] command bar script failed: %@", error[NSAppleScriptErrorMessage]);
}

static NSString *DPQuoted(NSString *text) {
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [NSString stringWithFormat:@"\"%@\"", [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

// By path, because the bundle ID can hit the original Dia when the iCloud Passwords relay has it open.
static NSString *DPSelf(void) { return [@"application " stringByAppendingString:DPQuoted(NSBundle.mainBundle.bundlePath)]; }

// nil unless Dia overrides this. NSObject's version returns an object and opens no tab.
static Class DPDirectTabClass(void) {
    static Class tab;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        SEL create = @selector(newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:);
        Class window = NSClassFromString(@"DiaAppleScriptWindow");
        if (window && class_getMethodImplementation(window, create) != class_getMethodImplementation(NSObject.class, create)) tab = NSClassFromString(@"DiaAppleScriptTab");
    });
    return tab;
}

BOOL DPBarCanOpenTabDirectly(void) { return DPDirectTabClass() != nil; }

// No script to compile and no Apple Event. Saved about 70 ms with 334 tabs open.
static BOOL DPOpenTabDirectly(NSWindow *window, NSString *url) {
    Class tab = DPDirectTabClass();
    if (!tab) return NO;
    @try {
        return [DPScriptedWindow(window) newScriptingObjectOfClass:tab forValueForKey:@"appleScriptTabs"
                                                 withContentsValue:nil properties:@{@"URL": url}] != nil;
    } @catch (NSException *e) {
        NSLog(@"[DiaPatches] command bar couldn't open a tab directly: %@", e);
        return NO;
    }
}

void DPBarOpenInNewTab(NSWindow *window, NSString *url) {
    if (!window.identifier || !url.length || DPOpenTabDirectly(window, url)) return;
    DPRunScript([NSString stringWithFormat:@"tell %@\n  tell (first window whose id is %@) to make new tab with properties {URL:%@}\nend tell",
                 DPSelf(), DPQuoted(window.identifier), DPQuoted(url)]);
}

void DPBarFocusTab(NSString *windowId, NSString *space, NSString *tabId) {
    if (!windowId || !tabId) return;
    NSString *owner = [NSString stringWithFormat:@"(first window whose id is %@)", DPQuoted(windowId)];
    if (space) owner = [NSString stringWithFormat:@"(first profile of %@ whose name is %@)", owner, DPQuoted(space)];
    DPRunScript([NSString stringWithFormat:@"tell %@\n  focus (first tab of %@ whose id is %@)\nend tell", DPSelf(), owner, DPQuoted(tabId)]);
}

static NSMutableDictionary<NSString *, NSNumber *> *DPTabLastUsed;

void DPBarNoteActiveTab(NSWindow *window) {
    static NSUInteger uses;
    @try {
        NSString *tab = [DPActiveTab(window) valueForKey:@"tabId"];
        if (!tab) return;
        if (!DPTabLastUsed) DPTabLastUsed = [NSMutableDictionary new];
        DPTabLastUsed[tab] = @(++uses);
    } @catch (__unused NSException *e) {}
}

static void DPAddTabs(NSMutableArray<DPBarItem *> *items, id owner, NSString *windowId, NSString *space) {
    for (id tab in [owner valueForKey:@"appleScriptTabs"]) {
        NSString *url = [tab valueForKey:@"URL"];
        if (![url isKindOfClass:NSString.class] || !url.length || [url hasPrefix:@"dia://"]) continue;
        DPBarItem *item = [DPBarItem new];
        item.kind = DPBarKindTab;
        item.title = [tab valueForKey:@"title"] ?: url;
        item.url = url;
        item.detail = @"Switch to Tab";
        item.tabId = [tab valueForKey:@"tabId"];
        item.windowId = windowId;
        item.space = space;
        item.symbol = @"square.on.square";
        item.frecency = 3;
        [items addObject:item];
    }
}

NSArray<DPBarItem *> *DPBarLoadTabs(NSWindow *window, NSString *space) {
    NSMutableArray<DPBarItem *> *items = [NSMutableArray new];
    @try {
        if (!space) DPAddTabs(items, DPScriptedWindow(window), window.identifier, nil);
        else for (id scripted in DPScriptedWindows()) {
            // Private windows are in this list too. They have no space, so this keeps their tabs out of normal windows.
            NSString *shown = DPSpaceOf(scripted), *windowId = [scripted valueForKey:@"windowId"];
            if (shown && DPCommandBarCoversAllSpaces()) {
                for (id profile in [scripted valueForKey:@"appleScriptProfiles"]) DPAddTabs(items, profile, windowId, [profile valueForKey:@"name"]);
            } else if ([shown isEqual:space]) DPAddTabs(items, scripted, windowId, shown);
        }
    } @catch (__unused NSException *e) {}
    NSMutableArray<DPBarItem *> *tabs = DPBarArrangeTabs(items, space, window.identifier);
    DPBarSortByRecency(tabs, DPTabLastUsed);
    return tabs;
}
