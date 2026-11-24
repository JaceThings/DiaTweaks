#import "HostInternal.h"
void DPEaselTrashDocument(DPEaselDocument *document,void (^completion)(NSError *)) {
    if(!document) return;
    [DPEaselHost finishEditingDocument:document];
    [DPEaselStore.shared trash:document completion:^(NSError *error) {
        if(!error) {
            // The scripting facade's close: is already used by DiaTweaks' tab
            // switcher. Snapshot lists because each close changes native tabs.
            for(id facade in [DPEaselRead(NSApp.delegate,@"appleScriptWindows") copy]) {
                for(id tab in [DPEaselRead(facade,@"appleScriptTabs") copy]) {
                    id value=DPEaselRead(tab,@"URL");
                    NSURL *url=[value isKindOfClass:NSURL.class] ? value : [value isKindOfClass:NSString.class] ? [NSURL URLWithString:value] : nil;
                    if(![[DPEaselStore.shared identifierForURL:url] isEqual:document.identifier] || ![tab respondsToSelector:@selector(close:)]) continue;
                    ((void (*)(id,SEL,id))objc_msgSend)(tab,@selector(close:),nil);
                }
            }
        }
        if(completion) completion(error);
    }];
}
