#import "HostInternal.h"
static NSString *DPEaselActiveURL(NSWindow *window) {
    for (id facade in DPEaselRead(NSApp.delegate, @"appleScriptWindows")) {
        if (![DPEaselRead(facade, @"windowId") isEqual:window.identifier]) continue;
        id value = DPEaselRead(DPEaselRead(facade, @"activeTab"), @"URL");
        if ([value isKindOfClass:NSURL.class]) return [value absoluteString];
        if ([value isKindOfClass:NSString.class]) return value;
    }
    return nil;
}
static char DPAddressAliasKey;
static NSHashTable<NSTextView *> *DPAddressFields;
static BOOL DPAddressScope(NSTextView *field) {
    for(NSView *parent=field.superview;parent;parent=parent.superview)
        if(DPIsKind(parent,DPDiaAddressField) || DPIsKind(parent,DPDiaCommandBarText)) return YES;
    return NO;
}
void DPEaselUpdateAddressField(NSTextView *field) {
    NSDictionary *alias=DPGet(field,&DPAddressAliasKey);
    if(!DPEasels.on || !DPAddressScope(field)) {
        DPSet(field,&DPAddressAliasKey,nil);
        if(alias && [field.string isEqual:alias[@"title"]]) field.string=alias[@"url"];
        return;
    }
    if(!DPAddressFields) DPAddressFields=NSHashTable.weakObjectsHashTable; [DPAddressFields addObject:field];
    NSWindow *window=field.window.parentWindow ?: field.window;
    NSString *current=DPEaselActiveURL(window); NSURL *url=[NSURL URLWithString:current ?: @""];
    DPEaselDocument *document=[DPEaselStore.shared cachedDocumentForURL:url];
    if(!document || document.deleted) { DPSet(field,&DPAddressAliasKey,nil); return; }
    NSString *value=field.string;
    BOOL raw=[value isEqual:current] || [value isEqual:current.stringByRemovingPercentEncoding] || [value isEqual:url.path];
    BOOL unchanged=alias && [alias[@"url"] isEqual:current] && [value isEqual:alias[@"title"]];
    if(!raw && !unchanged) { DPSet(field,&DPAddressAliasKey,nil); return; }
    NSString *title=DPEaselDisplayTitle(document.title);
    DPSet(field,&DPAddressAliasKey,@{@"url":current,@"title":title});
    if(![value isEqual:title]) {
        NSRange selected=field.selectedRange; [field.textStorage replaceCharactersInRange:NSMakeRange(0,value.length) withString:title];
        field.selectedRange=selected.length ? NSMakeRange(0,title.length) : NSMakeRange(MIN(selected.location,title.length),0);
    }
}
static void DPAddressLayout(NSView *view,SEL _cmd) {
    DPCallOriginal(DPAddressLayout,view);
    NSTextView *field=(id)DPFindView(view,^BOOL(NSView *child){ return [child isKindOfClass:NSTextView.class]; });
    if(field) DPEaselUpdateAddressField(field);
}
static void DPAddressString(NSTextView *field,SEL _cmd,NSString *value) {
    DPCallOriginal(DPAddressString,field,value);
    if([value hasPrefix:@"file:"] || DPGet(field,&DPAddressAliasKey)) DPEaselUpdateAddressField(field);
}
static void DPAddressCommand(NSTextView *field,SEL _cmd,SEL command) {
    NSDictionary *alias=DPGet(field,&DPAddressAliasKey);
    if(DPEasels.on && alias && command==@selector(insertNewline:) && [field.string isEqual:alias[@"title"]] && DPAddressScope(field)) {
        // The title is presentation, not a search query or a new navigation.
        DPCallOriginal(DPAddressCommand,field,@selector(cancelOperation:)); return;
    }
    DPCallOriginal(DPAddressCommand,field,command);
}
void DPEaselRefreshAddressFields(void) { for(NSTextView *field in DPAddressFields.allObjects) DPEaselUpdateAddressField(field); }
static void DPAddressScan(NSWindow *window) {
    if(!window || !DPEasels.on) return;
    DPFindView(window.contentView.superview ?: window.contentView,^BOOL(NSView *view){
        if([view isKindOfClass:NSTextView.class] && DPAddressScope((id)view)) DPEaselUpdateAddressField((id)view);
        return NO;
    });
}
void DPEaselInstallNativeAddress(void) {
    DPHook(DPDiaAddressField,@selector(layout),(IMP)DPAddressLayout);
    DPHook(DPDiaCommandBarText,@selector(layout),(IMP)DPAddressLayout);
    DPHookClass(NSTextView.class,@selector(setString:),(IMP)DPAddressString);
    DPHookClass(NSTextView.class,@selector(doCommandBySelector:),(IMP)DPAddressCommand);
    // Dia also rebuilds the native field through attributed text storage when
    // changing tab layouts. setString: and the old view's layout miss that path.
    [NSNotificationCenter.defaultCenter addObserverForName:NSTextStorageDidProcessEditingNotification object:nil queue:nil usingBlock:^(NSNotification *note){
        NSTextStorage *storage=note.object;
        if(!DPEasels.on || ![storage.string hasPrefix:@"file:"]) return;
        // TextKit 2 can expose NSTextStorage without legacy layout managers.
        for(NSTextView *field in DPAddressFields.allObjects) if(field.textStorage==storage) {
            __weak NSTextView *weak=field;
            dispatch_async(dispatch_get_main_queue(),^{ if(weak) DPEaselUpdateAddressField(weak); });
        }
        for(NSLayoutManager *manager in storage.layoutManagers) for(NSTextContainer *container in manager.textContainers) {
            NSTextView *field=container.textView; if(!DPAddressScope(field)) continue;
            __weak NSTextView *weak=field;
            dispatch_async(dispatch_get_main_queue(),^{ if(weak) DPEaselUpdateAddressField(weak); });
        }
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:DPEaselChanged object:nil queue:nil usingBlock:^(NSNotification *note){ DPEaselRefreshAddressFields(); }];
    for(NSNotificationName name in @[@"DPEaselHostDidMount",NSWindowDidBecomeKeyNotification])
        [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *note){
            __weak NSWindow *window=[note.object isKindOfClass:NSWindow.class] ? note.object : nil;
            dispatch_async(dispatch_get_main_queue(),^{ DPAddressScan(window); });
        }];
}
