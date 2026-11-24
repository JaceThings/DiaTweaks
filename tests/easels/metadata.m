#import "Patches/Easels/HostInternal.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
static IMP titleHook,iconHook;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {
    if(selector==@selector(title)) titleHook=replacement;
    if(selector==@selector(favicon)) iconHook=replacement;
}
static id NativeMetadata(id object,SEL selector) { return @"native metadata"; }
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return (IMP)NativeMetadata; }
@interface RestoredContents : NSObject
@property id url;
@property NSUInteger publications;
@end
@implementation RestoredContents
- (void)didChangeValueForKey:(NSString *)key { self.publications++; [super didChangeValueForKey:key]; }
@end
static id title(id contents) { return ((id (*)(id,SEL))titleHook)(contents,@selector(title)); }
static id icon(id contents) { return ((id (*)(id,SEL))iconHook)(contents,@selector(favicon)); }
static void spin(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.04]]; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselStore *writer=[[DPEaselStore alloc] initWithRoot:[NSURL fileURLWithPath:root]];
    DPEaselDocument *saved=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)];
    [saved rename:@"Restored before activation"]; [writer save:saved completion:nil]; [writer flush];
    DPEaselInstallMetadataHooks();
    RestoredContents *tab=RestoredContents.new; tab.url=[writer pageURL:saved.identifier];
    NSCAssert(![DPEaselStore.shared cachedDocumentForURL:tab.url],@"cold restored contents has no loaded document");
    NSCAssert([title(tab) isEqual:@"Untitled"] && [icon(tab) isKindOfClass:NSImage.class],@"cold tab gets a meaningful fallback and native icon immediately");
    NSDate *deadline=[NSDate dateWithTimeIntervalSinceNow:3];
    while(![title(tab) isEqual:saved.title] && deadline.timeIntervalSinceNow>0) spin();
    NSCAssert([title(tab) isEqual:saved.title],@"inactive native title resolves from the bounded summary without activating a page");
    NSCAssert(![DPEaselStore.shared cachedDocumentForURL:tab.url] && !DPEaselAttachmentFor(tab,NO),@"metadata lookup does not load a board or create an editor attachment");
    for(int i=0;i<8;i++) spin();
    NSCAssert(tab.publications>=2,@"async title completion republishes native title and favicon");
    RestoredContents *racing=RestoredContents.new; racing.url=tab.url;
    (void)title(racing);
    DPEaselDocument *live=[DPEaselStore.shared load:saved.identifier error:nil]; [live rename:@"Latest heading wins"];
    for(int i=0;i<10;i++) spin();
    NSCAssert([title(racing) isEqual:live.title] && [title(tab) isEqual:live.title],@"new heading reaches every placement and stale summary callback cannot replace it");
    RestoredContents *ordinary=RestoredContents.new; ordinary.url=[NSURL URLWithString:@"https://example.com/"];
    NSCAssert([title(ordinary) isEqual:@"native metadata"] && [icon(ordinary) isEqual:@"native metadata"],@"ordinary website metadata remains native");
    ordinary.url=@"not a URL object";
    NSCAssert([title(ordinary) isEqual:@"native metadata"],@"malformed native URL values safely fall through");
    racing.url=ordinary.url; NSUInteger before=racing.publications; [live rename:@"Another heading"];
    for(int i=0;i<8;i++) spin();
    NSCAssert(racing.publications==before && [title(racing) isEqual:@"native metadata"],@"late own-document metadata never leaks into a navigated ordinary page");
    DPEasels.on=NO; DPEaselRefreshMetadata();
    NSCAssert([title(tab) isEqual:@"native metadata"] && [icon(tab) isEqual:@"native metadata"],@"patch off restores native metadata getters");
    DPEasels.on=YES;
    NSCAssert([title(tab) isEqual:live.title],@"reenabling recovers current metadata without decoding every board");
    __weak RestoredContents *released;
    @autoreleasepool { RestoredContents *temporary=RestoredContents.new; temporary.url=tab.url; (void)title(temporary); released=temporary; }
    NSCAssert(!released,@"metadata observers and pending work do not retain native tab contents");
    [DPEaselStore.shared flush]; [writer flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: cold restored native titles/icons, summary-only loading, stale callback rejection, ordinary-tab isolation, toggle and lifetime cleanup");
} }
