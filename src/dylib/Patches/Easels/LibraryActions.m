#import "LibraryUI.h"
#import "Portable.h"
#import "Patches/SidebarLibrary/Library.h"
@implementation DPEaselLibraryContent (Actions)
- (void)openCard:(DPEaselCard *)card {
    NSError *error=nil; DPEaselDocument *document=[DPEaselStore.shared load:card.record[@"id"] error:&error];
    if(document && DPEaselOpen(self.library.window,document)) { self.library.previousResponder=nil; [self.library close]; return; }
    NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t open Easel";
    alert.informativeText=error.localizedDescription ?: @"This Dia window does not provide a compatible document tab.";
    if(!self.library.window.attachedSheet) [alert beginSheetModalForWindow:self.library.window completionHandler:nil];
}
- (void)deleteCard:(DPEaselCard *)card {
    if(self.removing) return;
    NSError *error=nil; DPEaselDocument *document=[DPEaselStore.shared load:card.record[@"id"] error:&error];
    if(!document) return;
    [self.window makeFirstResponder:card]; self.removing=YES; CGFloat alpha=card.alphaValue;
    DPLibraryDissolve(@[card],^{ card.alphaValue=alpha; card.hidden=YES; self.removing=NO; self.animateReflow=DPSidebarLibraryDust.on && !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion; [self setDocument:document trashed:YES]; });
}
- (void)restoreCard:(DPEaselCard *)card {
    DPEaselDocument *document=[DPEaselStore.shared loadTrashed:card.record[@"id"] error:nil];
    if(document) { [self.window makeFirstResponder:card]; [self setDocument:document trashed:NO]; }
}
- (void)toggleTrash:(id)sender {
    self.showTrash=!self.showTrash; self.recovery.contentTintColor=self.showTrash ? DPLibraryAccentColor(self.window) : NSColor.labelColor; self.recovery.needsDisplay=YES; self.loaded=NO; self.generation++; [self reload];
}
- (void)setDocument:(DPEaselDocument *)document trashed:(BOOL)trashed {
    BOOL ownGroup=self.undo.groupingLevel==0; if(ownGroup) [self.undo beginUndoGrouping];
    [self.undo registerUndoWithTarget:self handler:^(DPEaselLibraryContent *content){ [content setDocument:document trashed:!trashed]; }];
    [self.undo setActionName:trashed ? @"Delete Easel" : @"Restore Easel"];
    if(ownGroup) [self.undo endUndoGrouping];
    __weak DPEaselLibraryContent *weak=self;
    void (^completion)(NSError *)=^(NSError *error){
        DPEaselLibraryContent *content=weak; if(!content) return;
        if(error) {
            NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t update Easel"; alert.informativeText=error.localizedDescription;
            if(!content.window.attachedSheet) [alert beginSheetModalForWindow:content.window completionHandler:nil];
        }
        content.loaded=NO; [content reload];
    };
    if(trashed) DPEaselTrashDocument(document,completion);
    else [DPEaselStore.shared restore:document completion:completion];
}
- (void)importEasel:(id)sender { DPEaselPresentImport(self.library.window); }
- (void)newEasel:(id)sender {
    NSWindow *window=self.library.window; if(!DPEaselCanCreate(window)) return;
    [self.library close]; DPEaselCreate(window);
}
@end
