#import "HostInternal.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import "Patches/SidebarLibrary/Library.h"
static NSString *DPExistingEaselID(id value) {
    NSURL *url=[value isKindOfClass:NSURL.class] ? value : [value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil;
    return url ? [DPEaselStore.shared identifierForURL:url] : nil;
}
BOOL DPEaselCanCreate(NSWindow *window) {
    if(!DPEasels.on || !window || window.attachedSheet) return NO;
    id browser=DPBrowserOfWindow(window),context=DPEaselRead(browser,@"context"),identity=DPEaselRead(context,@"id");
    SEL private=NSSelectorFromString(@"isIncognito");
    return identity && [identity respondsToSelector:private] && !((BOOL (*)(id,SEL))objc_msgSend)(identity,private);
}
BOOL DPEaselOpen(NSWindow *window,DPEaselDocument *document) {
    if(!DPEaselCanCreate(window) || !document || document.deleted) return NO;
    NSURL *url=[DPEaselStore.shared pageURL:document.identifier];
    if(![NSFileManager.defaultManager fileExistsAtPath:url.path]) return NO;
    id browser=DPBrowserOfWindow(window);
    // Focus the native tab placement, not merely its backing WebContents.
    // The facade is shared by both sidebar tabs and horizontal tabs.
    for(id facade in DPEaselRead(NSApp.delegate,@"appleScriptWindows")) {
        if(![DPEaselRead(facade,@"windowId") isEqual:window.identifier]) continue;
        for(id tab in DPEaselRead(facade,@"appleScriptTabs")) {
            if([DPExistingEaselID(DPEaselRead(tab,@"URL")) isEqual:document.identifier] && [tab respondsToSelector:@selector(focus:)]) {
                ((void (*)(id,SEL,id))objc_msgSend)(tab,@selector(focus:),nil); return YES;
            }
        }
    }
    for(id contents in DPTrackedContents(browser)) {
        if([DPExistingEaselID(DPEaselRead(contents,@"url")) isEqual:document.identifier] && [contents respondsToSelector:@selector(activateTab:)])
            return ((BOOL (*)(id,SEL,NSError **))objc_msgSend)(contents,@selector(activateTab:),NULL);
    }
    for(id facade in DPEaselRead(NSApp.delegate,@"appleScriptWindows")) {
        if(![DPEaselRead(facade,@"windowId") isEqual:window.identifier]) continue;
        Class tabClass=NSClassFromString(@"DiaAppleScriptTab");
        SEL make=@selector(newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:);
        SEL insert=NSSelectorFromString(@"insertValue:atIndex:inPropertyWithKey:");
        if(!tabClass || ![facade respondsToSelector:make] || ![facade respondsToSelector:insert]) return NO;
        id tab=((id (*)(id,SEL,Class,id,id,id))objc_msgSend)(facade,make,tabClass,@"appleScriptTabs",nil,@{@"URL":url.absoluteString});
        if(!tab) return NO;
        NSArray *tabs=DPEaselRead(facade,@"appleScriptTabs");
        ((void (*)(id,SEL,id,NSUInteger,id))objc_msgSend)(facade,insert,tab,tabs.count,@"appleScriptTabs");
        if([tab respondsToSelector:@selector(focus:)]) ((void (*)(id,SEL,id))objc_msgSend)(tab,@selector(focus:),nil);
        return YES;
    }
    return NO;
}
void DPEaselCreate(NSWindow *window) {
    if(!DPEaselCanCreate(window) || ![(NSString *)DPLibraryContextForWindow(window) length]) return;
    NSView *page=DPFindView(window.contentView,^BOOL(NSView *view){ return DPIsKind(view,DPDiaContentContainer) && !view.hiddenOrHasHiddenAncestor; });
    NSSize size=page ? DPLibraryNativeFrame(page).size : NSMakeSize(900,720);
    size.height=MAX(1200,size.height+480);
    DPEaselDocument *document=[DPEaselDocument documentWithSize:size];
    document.profile=DPLibraryContextForWindow(window);
    __weak NSWindow *owner=window;
    [DPEaselStore.shared save:document completion:^(NSError *error) {
        if(!owner || !DPEasels.on) return;
        if(!error && DPEaselOpen(owner,document)) return;
        NSAlert *alert=NSAlert.new; alert.messageText=error ? @"Couldn’t save Easel" : @"Couldn’t open Easel";
        alert.informativeText=error.localizedDescription ?: @"The saved Easel has been kept. This Dia version did not provide a compatible tab host.";
        if(!owner.attachedSheet) [alert beginSheetModalForWindow:owner completionHandler:nil];
    }];
}
