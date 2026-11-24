#import "Patches/SidebarLibrary/Dust.h"
DPPatch DPSidebarLibraryDust={.on=YES};
void DPLibraryStopDissolves(void);
NSNotificationName const DPLibraryDownloadsChanged=@"DPLibraryFixtureChanged";
@interface DissolveFixture : NSView @end
@implementation DissolveFixture
- (void)drawRect:(NSRect)dirty { [@"Archived tab and favicon" drawAtPoint:NSMakePoint(20,30) withAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:20]}]; }
@end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSUserDefaults *prefs=[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    NSArray *keys=@[@"sidebarLibraryHiddenFiles",@"sidebarLibraryHiddenArchive"];
    NSMutableDictionary *saved=NSMutableDictionary.new; for(NSString *key in keys) saved[key]=[prefs objectForKey:key] ?: NSNull.null;
    NSString *profile=[@"Fixture-" stringByAppendingString:NSUUID.UUID.UUIDString];
    @try {
        DPLibraryFile *file=DPLibraryFile.new; file.identifier=@"same-id";
        DPLibraryFile *archive=DPLibraryFile.new; archive.identifier=@"same-id"; archive.archived=YES;
        DPLibrarySetHidden(profile,@[file],YES);
        NSCAssert([DPLibraryHiddenIDs(profile,NO) containsObject:@"same-id"] && !DPLibraryHiddenIDs(profile,YES).count,@"file hiding cannot hide archive entries");
        DPLibrarySetHidden(profile,@[archive],YES);
        DPLibrarySetHidden(profile,@[file],NO);
        NSCAssert(!DPLibraryHiddenIDs(profile,NO).count && DPLibraryHiddenIDs(profile,YES).count==1,@"individual restore preserves other record types");
        DPLibraryRestoreHidden(profile,YES);
        NSCAssert(!DPLibraryHiddenIDs(profile,YES).count,@"bulk restore clears only the current profile's archive hides");
        for(NSString *key in keys) {
            NSMutableDictionary *after=[[prefs dictionaryForKey:key] mutableCopy]; [after removeObjectForKey:profile];
            NSCAssert([after isEqual:(saved[key]==NSNull.null ? @{} : saved[key])],@"other profiles are unchanged");
        }
        NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,500,400) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
        NSView *view=[[DissolveFixture alloc] initWithFrame:NSMakeRect(20,20,440,320)]; [window.contentView addSubview:view];
        __block NSUInteger completions=0;
        DPLibraryDissolve(@[view],^{ completions++; });
        NSUInteger fragments=0; for(NSView *v in window.contentView.subviews) if([v isKindOfClass:DPLibraryDust.class]) fragments+=((DPLibraryDust *)v).samples.length/sizeof(DPLibraryParticle);
        NSCAssert(NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion || fragments>0,@"dissolve produces fine dust samples");
        NSCAssert(fragments<=24000,@"dissolve compositor work is bounded");
        NSDate *end=[NSDate dateWithTimeIntervalSinceNow:2];
        while(!completions && [end timeIntervalSinceNow]>0) [NSRunLoop.currentRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
        NSCAssert(completions==1 && view.alphaValue==1 && window.contentView.subviews.count==1,@"dissolve completes once and restores/removes temporary views");
        DPSidebarLibraryDust.on=NO;
        __block NSUInteger immediate=0; DPLibraryDissolve(@[view],^{immediate++;});
        NSCAssert(immediate==1 && view.alphaValue==1,@"disabled effect removes immediately without an animation");
        DPSidebarLibraryDust.on=YES;
        __block NSUInteger cancelled=0;DPLibraryDissolve(@[view],^{cancelled++;});DPLibraryStopDissolves();
        NSCAssert(cancelled==1 && view.alphaValue==1 && window.contentView.subviews.count==1,@"turning off the effect stops active dust and restores temporary state");
        printf("PASS: profile-scoped hide/restore, file/archive isolation; dissolve %lu fragments and cleanup\n",fragments);
    } @finally { for(NSString *key in keys) { if(saved[key]==NSNull.null) [prefs removeObjectForKey:key]; else [prefs setObject:saved[key] forKey:key]; } }
} }
