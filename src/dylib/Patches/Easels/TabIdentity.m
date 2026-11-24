#import "HostInternal.h"
NSString *DPEaselTabIdentifier(id row);
NSString *DPEaselIdentifierForTabRow(NSView *hit,NSWindow *window) {
    if(!DPEaselCanCreate(window)) return nil;
    NSString *tabID=nil;
    for(NSView *view=hit;view && !tabID;view=view.superview) tabID=DPEaselTabIdentifier(view);
    if(!tabID) return nil;
    for(id facade in DPEaselRead(NSApp.delegate,@"appleScriptWindows")) {
        if(![DPEaselRead(facade,@"windowId") isEqual:window.identifier]) continue;
        for(id tab in DPEaselRead(facade,@"appleScriptTabs")) if([DPEaselRead(tab,@"tabId") isEqual:tabID]) {
            id value=DPEaselRead(tab,@"URL"); NSURL *url=[value isKindOfClass:NSURL.class] ? value : [value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil;
            return url ? [DPEaselStore.shared identifierForURL:url] : nil;
        }
    }
    return nil;
}
