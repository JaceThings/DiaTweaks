#import "Easels.h"
#include <dlfcn.h>
void DPEaselRegisterAddressTitle(void) {
    typedef void (*RegisterTitle)(NSString *(^)(NSWindow *, NSString *));
    RegisterTitle registerTitle = (RegisterTitle)dlsym(RTLD_DEFAULT, "DPSidebarRegisterTitleProvider");
    if (!registerTitle) return;
    registerTitle(^NSString *(NSWindow *window,NSString *url){
        if(!DPEasels.on || ![url hasPrefix:@"file:"]) return nil;
        DPEaselDocument *document=[DPEaselStore.shared cachedDocumentForURL:[NSURL URLWithString:url]];
        return document && !document.deleted ? DPEaselDisplayTitle(document.title) : nil;
    });
}
