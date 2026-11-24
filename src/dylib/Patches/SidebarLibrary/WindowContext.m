#import "Library.h"
#import <objc/message.h>
NSString *DPIDKey(id value);
NSString *DPLibraryDirectoryForName(NSString *name);
static NSMapTable *DPSpaceContexts;
static id DPReadSpace(id object,NSString *key) {
    SEL selector = NSSelectorFromString(key);
    return [object respondsToSelector:selector] ? ((id (*)(id,SEL))objc_msgSend)(object,selector) : nil;
}
NSString *DPLibraryActiveSpace(NSWindow *window) {
    for (id facade in DPReadSpace(NSApp.delegate,@"appleScriptWindows")) {
        if (![DPReadSpace(facade,@"windowId") isEqual:window.identifier]) continue;
        return DPIDKey(DPSwiftValue(DPReadSpace(facade,@"activeProfile"),@"spaceID"));
    }
    return nil;
}
static NSString *DPLibraryActiveDirectory(NSWindow *window,BOOL *named) {
    for(id facade in DPReadSpace(NSApp.delegate,@"appleScriptWindows")) {
        if(![DPReadSpace(facade,@"windowId") isEqual:window.identifier]) continue;
        id name=DPReadSpace(DPReadSpace(facade,@"activeProfile"),@"name");
        if([name isKindOfClass:NSString.class] && [name length]) { if(named) *named=YES; return DPLibraryDirectoryForName(name); }
    }
    return nil;
}
void DPLibraryRememberWindowContext(NSWindow *window,NSString *context) {
    if (!window || !context) return;
    if (!DPSpaceContexts) DPSpaceContexts = [NSMapTable weakToStrongObjectsMapTable];
    NSString *space = DPLibraryActiveSpace(window); if (!space) return;
    NSMutableDictionary *contexts = [DPSpaceContexts objectForKey:window];
    if (!contexts) { contexts = [NSMutableDictionary new]; [DPSpaceContexts setObject:contexts forKey:window]; }
    BOOL named=NO; NSString *directory=DPLibraryActiveDirectory(window,&named);
    if(directory) { contexts[space]=directory; return; }
    if(named) return; // An ambiguous registry name must not learn a guessed attachment.
    // A delayed setWindow callback can arrive while the scripting facade
    // still names the previous space. Its established identity must win.
    if (!contexts[space]) contexts[space] = context;
}
NSString *DPLibraryResolveWindowContext(NSWindow *window,NSString *attachment) {
    NSString *space = DPLibraryActiveSpace(window);
    if (!space) return nil;
    BOOL named=NO; NSString *directory=DPLibraryActiveDirectory(window,&named);
    if(directory) { DPLibraryRememberWindowContext(window,directory); return directory; }
    NSString *known = [[DPSpaceContexts objectForKey:window] objectForKey:space];
    if (known) return known;
    if(named) return nil;
    DPLibraryRememberWindowContext(window,attachment);
    return [[DPSpaceContexts objectForKey:window] objectForKey:space];
}
