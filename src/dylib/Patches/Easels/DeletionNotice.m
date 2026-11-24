#import "Easels.h"
@interface DPEaselDeletionNotice : NSVisualEffectView
@property DPEaselDocument *document;
@property NSButton *undoButton;
- (void)undoDelete:(id)sender;
@end
@implementation DPEaselDeletionNotice
- (void)undoDelete:(id)sender {
    self.undoButton.enabled=NO; __weak DPEaselDeletionNotice *weak=self; NSWindow *window=self.window; DPEaselDocument *document=self.document;
    [DPEaselStore.shared restore:self.document completion:^(NSError *error) {
        DPEaselDeletionNotice *notice=weak;
        if(error) { notice.undoButton.enabled=YES; notice.undoButton.toolTip=error.localizedDescription; return; }
        if(window && DPEasels.on) DPEaselOpen(window,document);
        [notice removeFromSuperview];
    }];
}
@end
void DPEaselDeleteFromTab(NSWindow *window,DPEaselDocument *document) {
    if(!DPEaselCanCreate(window) || !document || document.deleted) return;
    __weak NSWindow *owner=window;
    DPEaselTrashDocument(document,^(NSError *error) {
        NSWindow *window=owner; if(!window) return;
        if(error) {
            NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t delete Easel"; alert.informativeText=error.localizedDescription;
            if(!window.attachedSheet) [alert beginSheetModalForWindow:window completionHandler:nil]; return;
        }
        if(!window.isVisible) return;
        for(NSView *view in window.contentView.subviews.copy) if([view isKindOfClass:DPEaselDeletionNotice.class]) [view removeFromSuperview];
        NSView *root=window.contentView; CGFloat width=MIN(340,MAX(180,NSWidth(root.bounds)-32));
        DPEaselDeletionNotice *notice=[[DPEaselDeletionNotice alloc] initWithFrame:NSMakeRect(NSWidth(root.bounds)-width-16,root.isFlipped ? NSHeight(root.bounds)-66 : 16,width,50)];
        notice.document=document; notice.material=NSVisualEffectMaterialPopover; notice.blendingMode=NSVisualEffectBlendingModeWithinWindow;
        notice.wantsLayer=YES; notice.layer.cornerRadius=12; notice.autoresizingMask=NSViewMinXMargin|(root.isFlipped ? NSViewMinYMargin : NSViewMaxYMargin);
        NSTextField *label=[NSTextField labelWithString:@"Easel moved to Recently Deleted"]; label.font=[NSFont systemFontOfSize:12]; label.frame=NSMakeRect(12,17,MAX(80,width-82),18); [notice addSubview:label];
        notice.undoButton=[NSButton buttonWithTitle:@"Undo" target:notice action:@selector(undoDelete:)]; notice.undoButton.bordered=NO;
        notice.undoButton.frame=NSMakeRect(width-64,9,56,32); notice.undoButton.accessibilityLabel=@"Undo Delete Easel"; [notice addSubview:notice.undoButton];
        [root addSubview:notice positioned:NSWindowAbove relativeTo:nil];
        __weak NSView *weak=notice;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,8*NSEC_PER_SEC),dispatch_get_main_queue(),^{ [weak removeFromSuperview]; });
    });
}
