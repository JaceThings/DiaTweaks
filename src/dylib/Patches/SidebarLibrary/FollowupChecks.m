#import "Library.h"
#ifdef DPLIBRARY_FOLLOWUP
DPLibraryController *DPLibraryForWindow(NSWindow *);
void DPLibraryInstallFollowupChecks(void) {
    DPOnLaunch(^{
        [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.library.followup" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            NSWindow *window = NSApp.keyWindow ?: NSApp.mainWindow;
            if (!window) return;
            DPLibraryController *c = DPLibraryForWindow(window);
            if ([note.object hasPrefix:@"hold="]) {
                [c.motion stopAnimation]; c.motion=nil; c.interacting=YES;
                if (!c.expanded) [c showAnimated:NO];
                c.expansion=[[note.object substringFromIndex:5] doubleValue]; DPLibraryUpdateHosts(c);
                // Force the same native relayout that used to reset tab layers.
                [c.sidebarHost setNeedsLayout:YES]; [c.sidebarHost layoutSubtreeIfNeeded]; [c layout];
                NSMutableArray *surfaces=[NSMutableArray new];
                for (NSView *v in c.sidebarHost.subviews) if ([v.identifier isEqual:@"DiaTweaks.SidebarLibrary.NativeSnapshot"]) [surfaces addObject:@{@"frame":NSStringFromRect(v.frame),@"image":@(((NSImageView *)v).image!=nil),@"visible":@(!v.hidden)}];
                [@{@"progress":@(c.expansion),@"surfaces":surfaces} writeToFile:@"/tmp/library-followup-hold.plist" atomically:YES];
            } else if ([note.object isEqual:@"preview"]) {
                DPLibraryDismissForWindow(window);
                NSView *entry=DPFindView(window.contentView,^BOOL(NSView *v){return [v.identifier isEqual:@"DiaTweaks.SidebarLibrary.Button"] && !v.hiddenOrHasHiddenAncestor;});
                [entry mouseEntered:nil];
            } else if ([note.object isEqual:@"close"]) { [c close]; }
        }];
    });
}
#endif
