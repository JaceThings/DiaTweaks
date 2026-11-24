#import "Patches/SidebarLibrary/Library.h"
#import <objc/message.h>
DPPatch DPSidebarLibrary;
void DPLibraryDismissForWindow(NSWindow *window) {}
void DPLibraryRememberWindowContext(NSWindow *window,NSString *context) {}
NSString *DPLibraryResolveWindowContext(NSWindow *window,NSString *attachment) { return attachment; }
static NSMutableDictionary<NSString *,NSValue *> *hooks;
void DPHook(const char *name, SEL selector, IMP replacement) { hooks[NSStringFromSelector(selector)] = [NSValue valueWithPointer:replacement]; }
static void original(id object, SEL selector, ...) {}
IMP DPOriginalIMP(id object, SEL selector, IMP replacement) { return (IMP)original; }
IMP DPPushOriginalIMP(id object, SEL selector, IMP replacement, DPHookFrame *frame) {
    return DPOriginalIMP(object, selector, replacement);
}
void DPPopOriginalIMP(DPHookFrame *frame) {}
BOOL DPIsKind(id object, const char *name) { return [object isKindOfClass:NSClassFromString(@(name))]; }
@interface LibraryIdentity : NSObject
@property NSString *directoryBasename;
@property BOOL isIncognito;
@end
@implementation LibraryIdentity @end
@interface LibraryContext : NSObject
@property LibraryIdentity *id;
@end
@implementation LibraryContext @end
@interface ArcDownloadItem : NSObject
@property NSString *id, *targetPath, *sourceURL;
@property NSDate *startTime;
@property NSInteger currentState;
@property long long completedBytes,totalBytes;
@end
@implementation ArcDownloadItem @end
static LibraryContext *context(NSString *name, BOOL private) {
    LibraryContext *value = [LibraryContext new]; value.id = [LibraryIdentity new];
    value.id.directoryBasename = name; value.id.isIncognito = private; return value;
}
static ArcDownloadItem *item(NSString *key, NSString *path, NSInteger state) {
    ArcDownloadItem *value = [ArcDownloadItem new]; value.id = key; value.targetPath = path;
    value.sourceURL = @"https://example.com/file"; value.startTime = [NSDate dateWithTimeIntervalSince1970:100];
    value.currentState = state; value.totalBytes = 100; value.completedBytes = 50; return value;
}
static void callback(NSString *name,id profile,id value) {
    void (*call)(id,SEL,id,id) = hooks[name].pointerValue;
    NSCAssert(call,@"hook exists"); call(nil,NSSelectorFromString(name),profile,value);
}
int main(void) { @autoreleasepool {
    hooks = [NSMutableDictionary new]; DPLibraryInstallDownloads();
    NSString *folder = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [NSFileManager.defaultManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    NSString *beach = [folder stringByAppendingPathComponent:@"Beach.png"];
    NSString *other = [folder stringByAppendingPathComponent:@"Other.png"];
    [@"fixture" writeToFile:beach atomically:YES encoding:NSUTF8StringEncoding error:nil];
    [@"fixture" writeToFile:other atomically:YES encoding:NSUTF8StringEncoding error:nil];
    LibraryContext *first = context(@"library-fixture-1",NO), *second = context(@"library-fixture-2",NO), *private = context(@"library-fixture-private",YES);
    ArcDownloadItem *image = item(@"a",beach,2), *text = item(@"b",@"/tmp/Notes.txt",1);
    callback(@"browserContext:downloadManagerInitializedWithItems:",first,@[image,text]);
    callback(@"browserContext:downloadManagerInitializedWithItems:",second,@[item(@"a",other,2)]);
    callback(@"browserContext:downloadManagerInitializedWithItems:",private,@[image]);
    NSCAssert(DPLibraryFiles(first).count == 2,@"initial browser history captured");
    NSCAssert(DPLibraryFiles(context(@"library-fixture-1",NO)).count == 2,@"new native facade resolves the same stable profile");
    NSCAssert(DPLibraryFiles(second).count == 1,@"same download ID does not cross profiles");
    NSCAssert(DPLibraryFiles(private).count == 0,@"private context excluded");
    NSCAssert(DPLibraryFiles(nil).count == 0,@"unresolved window never sees another profile");
    NSArray<DPLibraryFile *> *shared=DPLibraryFiltered(DPLibrarySharedMediaFiles(NO),@"",0,YES);
    NSCAssert(shared.count==2,@"Media includes images from both normal profiles");
    NSCAssert(![shared[0].key isEqual:shared[1].key],@"same native download ID has distinct shared-media selection keys");
    NSArray *files = DPLibraryFiles(first);
    NSCAssert(DPLibraryFiltered(files,@"beach",0,YES).count == 1,@"media search is case insensitive");
    NSCAssert(DPLibraryFiltered(files,@"",2,NO).count == 1,@"progress filter");
    NSCAssert(DPLibraryFiltered(files,@"missing",0,NO).count == 0,@"real empty search");
    image.targetPath = @"/tmp/Renamed.png";
    callback(@"browserContext:onDownloadUpdated:",first,image);
    NSCAssert(DPLibraryFiltered(DPLibraryFiles(first),@"renamed",0,NO).count == 1,@"Tidy Names path update");
    callback(@"browserContext:onDownloadRemoved:",first,image);
    NSCAssert(DPLibraryFiles(first).count == 1,@"removed history entry disappears");
    NSCAssert(DPLibraryFiles(second).count == 1,@"removal stays within context");
    callback(@"browserContext:downloadManagerInitializedWithItems:",first,@[]);
    NSCAssert(DPLibraryFiles(first).count==0,@"cleared authoritative history replaces cached records even with an empty snapshot");
    NSCAssert(DPLibraryFiles(second).count==1,@"history clear does not affect another profile");
    callback(@"browserContext:downloadManagerInitializedWithItems:",first,@[text]);
    NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    id originalHidden = [settings objectForKey:@"sidebarLibraryHiddenFiles"];
    @try {
        DPLibraryHideFiles(second,DPLibraryFiles(second));
        NSCAssert(DPLibraryFiles(second).count == 0,@"Hide from Library persists only the selected profile's IDs");
        NSCAssert(DPLibraryFiles(first).count == 1,@"hiding never crosses profiles");
        NSCAssert(DPLibrarySharedMediaFiles(YES).count==1,@"hidden shared Media remains recoverable in its owning profile");
    } @finally {
        if (originalHidden) [settings setObject:originalHidden forKey:@"sidebarLibraryHiddenFiles"];
        else [settings removeObjectForKey:@"sidebarLibraryHiddenFiles"];
    }
    [NSFileManager.defaultManager removeItemAtPath:folder error:nil];
    puts("PASS: initial history, profile isolation, private exclusion, filters, renamed paths and removal");
} }
