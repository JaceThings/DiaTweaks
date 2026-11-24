#import "Library.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import <objc/message.h>

NSNotificationName const DPLibraryDownloadsChanged = @"DPLibraryDownloadsChanged";
static NSMutableDictionary<NSString *,NSMutableDictionary *> *DPDownloadContexts;
static NSMapTable *DPWindowContexts;
static NSMutableDictionary *DPNativeContexts;
id DPLibraryNativeContext(NSString *profile) { return profile ? DPNativeContexts[profile] : nil; }
static BOOL DPNotifyPending;
void DPLibraryRememberWindowContext(NSWindow *window,NSString *context);
NSString *DPLibraryResolveWindowContext(NSWindow *window,NSString *attachment);
#ifdef DPLIBRARY_DIAGNOSTICS
static NSUInteger DPInitialCalls, DPUpdatedCalls, DPRejected;
#endif
static id DPReadLibrary(id object, NSString *key) {
    SEL selector = NSSelectorFromString(key);
    return [object respondsToSelector:selector] ? ((id (*)(id, SEL))objc_msgSend)(object, selector) : nil;
}
static NSString *DPProfileKey(id context) {
    if ([context isKindOfClass:NSString.class]) return context;
    id identity = DPReadLibrary(context,@"id");
    SEL private = NSSelectorFromString(@"isIncognito");
    if (![identity respondsToSelector:private] || ((BOOL (*)(id,SEL))objc_msgSend)(identity,private)) return nil;
    id value = DPReadLibrary(identity,@"directoryBasename");
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}
static void DPDownloadNotify(void) {
    if (DPNotifyPending || !DPSidebarLibrary.on) return;
    DPNotifyPending = YES;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        DPNotifyPending = NO;
        [NSNotificationCenter.defaultCenter postNotificationName:DPLibraryDownloadsChanged object:nil];
    });
}
static void DPRememberLibraryDownload(id context, id item) {
#ifdef DPLIBRARY_DIAGNOSTICS
    DPUpdatedCalls++;
#endif
    id identity = DPReadLibrary(context,@"id");
    if (!identity || ![identity respondsToSelector:NSSelectorFromString(@"isIncognito")] ||
        ((BOOL (*)(id,SEL))objc_msgSend)(identity,NSSelectorFromString(@"isIncognito")) || !DPIsKind(item,"ArcDownloadItem")) {
#ifdef DPLIBRARY_DIAGNOSTICS
        DPRejected++;
#endif
        return;
    }
    NSString *key = DPReadLibrary(item,@"id");
    if (![key isKindOfClass:NSString.class] || !key.length) return;
    NSString *profile = DPProfileKey(context); if (!profile) return;
    DPNativeContexts[profile] = context;
    NSMutableDictionary *items = DPDownloadContexts[profile];
    if (!items) DPDownloadContexts[profile] = items = [NSMutableDictionary new];
    items[key] = item;
    DPDownloadNotify();
}
static void DPLibraryInitialized(id self, SEL _cmd, id context, NSArray *items) {
    DPCallOriginal(DPLibraryInitialized,self,context,items);
    NSString *profile = DPProfileKey(context);
    if (profile) { DPNativeContexts[profile] = context; DPDownloadContexts[profile] = NSMutableDictionary.new; }
#ifdef DPLIBRARY_DIAGNOSTICS
    DPInitialCalls++;
#endif
    for (id item in items) DPRememberLibraryDownload(context,item);
    if (profile) DPDownloadNotify();
}
static void DPLibraryUpdated(id self, SEL _cmd, id context, id item) {
    DPCallOriginal(DPLibraryUpdated,self,context,item);
    DPRememberLibraryDownload(context,item);
}
static void DPLibraryCreated(id self, SEL _cmd, id context, id item) {
    DPCallOriginal(DPLibraryCreated,self,context,item);
    DPRememberLibraryDownload(context,item);
}
static void DPLibraryRemoved(id self, SEL _cmd, id context, id item) {
    DPCallOriginal(DPLibraryRemoved,self,context,item);
    NSString *key = DPReadLibrary(item,@"id");
    NSString *profile = DPProfileKey(context);
    if (profile) DPNativeContexts[profile] = context;
    if (key && profile) [DPDownloadContexts[profile] removeObjectForKey:key];
    DPDownloadNotify();
}
static void DPLibraryBrowserWindow(id self, SEL _cmd, NSWindow *window) {
    DPCallOriginal(DPLibraryBrowserWindow,self,window);
    id context = DPReadLibrary(self,@"context");
    NSString *profile = DPProfileKey(context);
    if (profile) DPNativeContexts[profile] = context;
    // Background browser attachments are not proof of an active-space change.
    // The window observer dismisses only on a confirmed stable space ID change.
    if (window && profile) [DPWindowContexts setObject:profile forKey:window];
    else if (window) [DPWindowContexts removeObjectForKey:window];
    if (window && profile) dispatch_async(dispatch_get_main_queue(),^{
        if ([[DPWindowContexts objectForKey:window] isEqual:profile]) DPLibraryRememberWindowContext(window,profile);
    });
}
id DPLibraryContextForWindow(NSWindow *window) { return DPLibraryResolveWindowContext(window,[DPWindowContexts objectForKey:window]); }
void DPLibraryHideFiles(id context, NSArray<DPLibraryFile *> *files) {
    DPLibrarySetHidden(DPProfileKey(context),files,YES); DPDownloadNotify();
}

NSArray<DPLibraryFile *> *DPLibraryAllFiles(id context) {
    NSMutableArray *files = [NSMutableArray new];
    NSString *profile = DPProfileKey(context); if (!profile) return files;
#ifdef DPLIBRARY_DIAGNOSTICS
    NSDictionary *status = @{@"contexts":@(DPDownloadContexts.count),@"windows":@(DPWindowContexts.count),
        @"resolved":@(context != nil),@"initialCalls":@(DPInitialCalls),@"updatedCalls":@(DPUpdatedCalls),@"rejected":@(DPRejected),
        @"currentRecords":@([DPDownloadContexts[profile] count])};
    [[NSJSONSerialization dataWithJSONObject:status options:0 error:nil] writeToFile:@"/tmp/sidebar-library-runtime.json" atomically:YES];
#endif
    for (id item in [DPDownloadContexts[profile] allValues]) {
        DPLibraryFile *file = [DPLibraryFile new]; file.profile=profile;
        file.identifier = DPReadLibrary(item,@"id"); file.path = DPReadLibrary(item,@"targetPath");
        file.source = DPReadLibrary(item,@"sourceURL"); file.date = DPReadLibrary(item,@"startTime") ?: NSDate.distantPast;
        file.state = ((NSInteger (*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"currentState"));
        file.completed = ((long long (*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"completedBytes"));
        file.total = ((long long (*)(id,SEL))objc_msgSend)(item,NSSelectorFromString(@"totalBytes"));
        SEL remaining = NSSelectorFromString(@"remainingTimeInSeconds"), paused = NSSelectorFromString(@"isPaused");
        file.remaining = [item respondsToSelector:remaining] ? ((long long (*)(id,SEL))objc_msgSend)(item,remaining) : -1;
        file.paused = [item respondsToSelector:paused] && ((BOOL (*)(id,SEL))objc_msgSend)(item,paused);
        [files addObject:file];
    }
#ifdef DPLIBRARY_DIAGNOSTICS
    NSMutableArray *counts = [NSMutableArray new];
    for (NSDictionary *items in DPDownloadContexts.allValues) [counts addObject:@(items.count)];
    NSUInteger media = 0, existing = 0;
    for (DPLibraryFile *file in files) if (DPLibraryIsMedia(file)) {
        media++; if ([NSFileManager.defaultManager fileExistsAtPath:file.path]) existing++;
    }
    NSDictionary *details = @{@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"profileRecordCounts":counts,
        @"currentRecords":@(files.count),@"currentMedia":@(media),@"existingMedia":@(existing)};
    [[NSJSONSerialization dataWithJSONObject:details options:0 error:nil] writeToFile:@"/tmp/sidebar-library-profile-counts.json" atomically:YES];
#endif
    return files;
}
void DPLibraryInstallDownloads(void) {
    DPDownloadContexts = [NSMutableDictionary new];
    DPNativeContexts = [NSMutableDictionary new];
    DPWindowContexts = [NSMapTable weakToStrongObjectsMapTable];
    const char *bridge = "_TtC3ADK36BrowserContextDownloadDelegateBridge";
    DPHook(bridge,NSSelectorFromString(@"browserContext:downloadManagerInitializedWithItems:"),(IMP)DPLibraryInitialized);
    DPHook(bridge,NSSelectorFromString(@"browserContext:onDownloadUpdated:"),(IMP)DPLibraryUpdated);
    DPHook(bridge,NSSelectorFromString(@"browserContext:onDownloadCreated:"),(IMP)DPLibraryCreated);
    DPHook(bridge,NSSelectorFromString(@"browserContext:onDownloadRemoved:"),(IMP)DPLibraryRemoved);
    DPHook(DPDiaBrowser,@selector(setWindow:),(IMP)DPLibraryBrowserWindow);
}

NSArray<DPLibraryFile *> *DPLibraryFiles(id context) {
    NSSet *hidden=DPLibraryHiddenIDs(DPProfileKey(context),NO);
    return [DPLibraryAllFiles(context) filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DPLibraryFile *file,NSDictionary *bindings) { return ![hidden containsObject:file.identifier]; }]];
}

NSArray<DPLibraryFile *> *DPLibrarySharedMediaFiles(BOOL hidden) {
    NSMutableArray *files=NSMutableArray.new;
    for(NSString *profile in DPDownloadContexts.allKeys) {
        NSSet *ids=DPLibraryHiddenIDs(profile,NO);
        for(DPLibraryFile *file in DPLibraryAllFiles(profile)) if([ids containsObject:file.identifier]==hidden) [files addObject:file];
    }
    return files;
}
NSUInteger DPLibraryHiddenMediaCount(void) {
    NSUInteger count=0; for(NSString *profile in DPDownloadContexts.allKeys) count+=DPLibraryHiddenIDs(profile,NO).count; return count;
}
void DPLibraryRestoreHiddenMedia(void) {
    for(NSString *profile in DPDownloadContexts.allKeys) DPLibraryRestoreHidden(profile,NO);
}
