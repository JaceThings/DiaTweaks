#import "Library.h"
@implementation DPLibraryController (Options)
- (void)toggleHidden:(id)sender { self.showHidden=!self.showHidden; self.listingState=nil; [self reload]; }
- (void)restoreAllHidden:(id)sender {
    if([self.section isEqual:@"Media"]) DPLibraryRestoreHiddenMedia(); else DPLibraryRestoreHidden(self.context,[self.section isEqual:@"Archived Tabs"]); self.listingState=nil; [self reload];
}
- (void)clearLibraryArchive:(id)sender {
    if (![self.section isEqual:@"Archived Tabs"] || !self.archive.count || self.removing) return;
    NSAlert *alert=NSAlert.new; alert.messageText=@"Clear this profile’s Library Archive?";
    alert.informativeText=@"These entries will be hidden from Library. You can restore them from Library options → Show Hidden Items. Dia’s native archive and browsing history stay intact.";
    [alert addButtonWithTitle:@"Clear Library Archive"]; [alert addButtonWithTitle:@"Cancel"];
    NSString *profile=self.context; NSArray *records=self.archive;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result!=NSAlertFirstButtonReturn || ![self.context isEqual:profile]) return;
        self.removing=YES;
        DPLibraryDissolve(@[self.table],^{ DPLibrarySetHidden(profile,records,YES); self.removing=NO; self.animateRemoval=DPSidebarLibraryDust.on && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; self.listingState=nil; [self reload]; });
    }];
}
- (void)showOptions:(id)sender {
    NSMenu *menu=NSMenu.new;
    NSMenuItem *hidden=[[NSMenuItem alloc] initWithTitle:@"Show Hidden Items" action:@selector(toggleHidden:) keyEquivalent:@""];
    hidden.state=self.showHidden; hidden.target=self; [menu addItem:hidden];
    NSMenuItem *restore=[[NSMenuItem alloc] initWithTitle:@"Restore All Hidden Items" action:@selector(restoreAllHidden:) keyEquivalent:@""];
    restore.target=self; restore.enabled=[self.section isEqual:@"Media"] ? DPLibraryHiddenMediaCount()>0 : DPLibraryHiddenIDs(self.context,[self.section isEqual:@"Archived Tabs"]).count>0; [menu addItem:restore];
    if ([self.section isEqual:@"Archived Tabs"]) {
        [menu addItem:NSMenuItem.separatorItem];
        NSMenuItem *clear=[[NSMenuItem alloc] initWithTitle:@"Clear Library Archive…" action:@selector(clearLibraryArchive:) keyEquivalent:@""];
        clear.target=self; clear.enabled=self.archive.count>0; [menu addItem:clear];
    }
    menu.autoenablesItems=NO;
    [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0,NSHeight(self.options.bounds)) inView:self.options];
}
- (void)restoreSelection:(id)sender { DPLibrarySetHidden(self.context,self.selectedFiles,NO); self.listingState=nil; [self reload]; }
- (void)copyImage:(id)sender {
    DPLibraryFile *file=self.selectedFiles.firstObject; NSImage *image=[[NSImage alloc] initWithContentsOfFile:file.path];
    if (!image) { NSBeep(); return; }
    [NSPasteboard.generalPasteboard clearContents]; [NSPasteboard.generalPasteboard writeObjects:@[image]];
}
- (void)trashSelection:(id)sender {
    NSArray *urls=self.selectedFileURLs;
    [NSWorkspace.sharedWorkspace recycleURLs:urls completionHandler:^(NSDictionary *newURLs,NSError *error) {
        dispatch_async(dispatch_get_main_queue(),^{ if (error) [NSApp presentError:error]; self.listingState=nil; [self reload]; });
    }];
}
@end
