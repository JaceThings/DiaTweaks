#import "Patches/SidebarLibrary/Library.h"
#import <stdatomic.h>
static atomic_uint lookups;
id DPLibraryNativeContext(NSString *profile) { return nil; }
NSImage *DPLibraryFaviconFromDatabase(NSString *profile,NSURL *url) {
    atomic_fetch_add(&lookups,1); return [NSImage imageWithSystemSymbolName:@"globe" accessibilityDescription:nil];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; __block NSUInteger completed=0; NSUInteger expected=82;
    for(NSUInteger i=0;i<80;i++) {
        DPLibraryFavicon(@"fixture",[NSString stringWithFormat:@"https://host%lu.example/page",i],^(NSImage *image) { NSCAssert(image,@"queued lookups are not dropped"); completed++; });
    }
    DPLibraryFavicon(@"fixture",@"https://host0.example/another-page",^(NSImage *image) { NSCAssert(image,@"coalesced callers receive the result"); completed++; });
    DPLibraryFavicon(@"other-profile",@"https://host0.example/another-page",^(NSImage *image) { NSCAssert(image,@"profile cache stays separate"); completed++; });
    NSDate *end=[NSDate dateWithTimeIntervalSinceNow:3];
    while(completed<expected && [end timeIntervalSinceNow]>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(completed==expected && atomic_load(&lookups)==81,@"queue drains and origins coalesce without mixing profiles");
    puts("PASS: 82 favicon callers complete, 81 origin/profile lookups, no saturation drops");
} }
