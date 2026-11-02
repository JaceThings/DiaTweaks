#import "DeveloperMode.h"

// Dia opens its developer panels from menu actions and then calls openInspectView, openConsoleView or openNetworkView on
// the tab's DevTools. Those calls are watched to learn which panel each tab shows, and Dia's own toggle action closes it.

@interface NSObject (DPDevTools)
- (void)openNetworkView;
- (id)toolboxWebContents;  // Set while DevTools is open.
@end

static NSMapTable<NSString *, id> *DPToolsByTab;
static NSMutableDictionary<NSString *, NSNumber *> *DPPanelByTab;
static BOOL DPNetworkNext;

static void DPNote(id tools, DPDevPanel panel) {
    NSString *tab = DPActiveTabID(DPFrontBrowserWindow());
    if (!tab) return;
    [DPToolsByTab setObject:tools forKey:tab];
    DPPanelByTab[tab] = @(panel);
}

static void DPDevTools_openInspectView(id self, SEL _cmd) {
    DPNote(self, DPPanelInspect);
    DPCallOriginal(DPDevTools_openInspectView, self);
}

// Dia has no menu action for the network panel. Its console action opens a tab's DevTools, so that call is sent there.
static void DPDevTools_openConsoleView(id self, SEL _cmd) {
    if (!DPNetworkNext) {
        DPNote(self, DPPanelConsole);
        return DPCallOriginal(DPDevTools_openConsoleView, self);
    }
    DPNetworkNext = NO;
    DPNote(self, DPPanelNetwork);
    [self openNetworkView];
}

static void DPDevTools_close(id self, SEL _cmd) {
    for (NSString *tab in DPToolsByTab.keyEnumerator.allObjects)
        if ([DPToolsByTab objectForKey:tab] == self) [DPPanelByTab removeObjectForKey:tab];
    DPCallOriginal(DPDevTools_close, self);
}

void DPInstallDevPanels(void) {
    DPToolsByTab = [NSMapTable strongToWeakObjectsMapTable];
    DPPanelByTab = [NSMutableDictionary new];
    DPHook("ArcWebContentsDevTools", @selector(openInspectView), (IMP)DPDevTools_openInspectView);
    DPHook("ArcWebContentsDevTools", @selector(openConsoleView), (IMP)DPDevTools_openConsoleView);
    DPHook("ArcWebContentsDevTools", @selector(close), (IMP)DPDevTools_close);
}

DPDevPanel DPShownDevPanel(NSWindow *window) {
    NSString *tab = DPActiveTabID(window);
    id tools = tab ? [DPToolsByTab objectForKey:tab] : nil;
    return [tools toolboxWebContents] ? [DPPanelByTab[tab] integerValue] : DPPanelNone;
}

void DPToggleDevPanel(DPDevPanel panel, NSWindow *window) {
    if (DPShownDevPanel(window) == panel) {
        [NSApp sendAction:@selector(toggleDevTools:) to:nil from:nil];
        return;
    }
    DPNetworkNext = panel == DPPanelNetwork;
    [NSApp sendAction:panel == DPPanelInspect ? @selector(inspectElements:) : @selector(openJavaScriptConsole:) to:nil from:nil];
    DPNetworkNext = NO;
}
