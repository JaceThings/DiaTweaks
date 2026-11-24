#import "Library.h"
#import <objc/message.h>
static id DPLibraryReadScript(id object, NSString *name) {
    SEL selector = NSSelectorFromString(name);
    return [object respondsToSelector:selector] ? ((id (*)(id,SEL))objc_msgSend)(object,selector) : nil;
}
BOOL DPLibraryOpenArchivedURL(NSWindow *window,NSURL *url) {
    if (!window || !DPLibraryCanOpenArchivedURL(url)) return NO;
    for (id facade in DPLibraryReadScript(NSApp.delegate,@"appleScriptWindows")) {
        if (![DPLibraryReadScript(facade,@"windowId") isEqual:window.identifier]) continue;
        Class tabClass = NSClassFromString(@"DiaAppleScriptTab");
        SEL create = @selector(newScriptingObjectOfClass:forValueForKey:withContentsValue:properties:);
        SEL insert = NSSelectorFromString(@"insertValue:atIndex:inPropertyWithKey:");
        if (!tabClass || ![facade respondsToSelector:create] || ![facade respondsToSelector:insert]) return NO;
        id tab = ((id (*)(id,SEL,Class,id,id,id))objc_msgSend)(facade,create,tabClass,@"appleScriptTabs",nil,@{@"URL":url.absoluteString});
        if (!tab) return NO;
        NSArray *tabs = DPLibraryReadScript(facade,@"appleScriptTabs");
        ((void (*)(id,SEL,id,NSUInteger,id))objc_msgSend)(facade,insert,tab,tabs.count,@"appleScriptTabs");
        return YES;
    }
    return NO;
}
