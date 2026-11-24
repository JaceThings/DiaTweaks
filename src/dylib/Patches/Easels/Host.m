#import "HostInternal.h"
#import "Canvas.h"
#import "Portable.h"

static NSMapTable *DPAttachments;
id DPEaselRead(id object,NSString *key) {
    SEL selector=NSSelectorFromString(key);
    return [object respondsToSelector:selector] ? ((id (*)(id,SEL))objc_msgSend)(object,selector) : nil;
}
DPEaselAttachment *DPEaselAttachmentFor(id contents,BOOL create) {
    if(!DPAttachments) DPAttachments=NSMapTable.weakToStrongObjectsMapTable;
    DPEaselAttachment *attachment=[DPAttachments objectForKey:contents];
    if(!attachment && create) {
        attachment=DPEaselAttachment.new; attachment.contents=contents;
        [DPAttachments setObject:attachment forKey:contents];
    }
    if(attachment && !attachment.observing && DPEasels.on) {
        id navigation=DPEaselRead(contents,@"navigationController");
        if([navigation respondsToSelector:@selector(addObserver:)])
            ((void (*)(id,SEL,id))objc_msgSend)(navigation,@selector(addObserver:),attachment);
        attachment.observing=[navigation respondsToSelector:@selector(addObserver:)];
    }
    return attachment;
}
void DPEaselBindPane(id contents,NSView *pane) {
    // Dia reuses a pane for successive tabs without always detaching the old
    // contents first. A pane may own exactly one native Easel overlay.
    if(pane) for(id other in DPAttachments.keyEnumerator) {
        DPEaselAttachment *previous=[DPAttachments objectForKey:other];
        if(other!=contents && previous.pane==pane) { previous.pane=nil; [previous refresh]; }
    }
    DPEaselAttachment *attachment=DPEaselAttachmentFor(contents,YES);
    if(attachment.pane!=pane) attachment.provisionalNavigation=NO;
    attachment.pane=pane; [attachment refresh];
}
@implementation DPEaselAttachment
- (void)refresh {
    if(!NSThread.isMainThread || self.creatingEditor) return;
    if(!DPEasels.on || !self.pane) {
        self.provisionalNavigation=NO;
        [self.titleDelay invalidate]; self.titleDelay=nil;
        [self.editor removeFromSuperview]; self.editor=nil; self.document=nil;
        if(self.observing) {
            id navigation=DPEaselRead(self.contents,@"navigationController");
            if([navigation respondsToSelector:@selector(removeObserver:)])
                ((void (*)(id,SEL,id))objc_msgSend)(navigation,@selector(removeObserver:),self);
            self.observing=NO;
        }
        return;
    }
    if(self.provisionalNavigation) { [self.editor removeFromSuperview]; return; }
    id url=DPEaselRead(self.contents,@"url");
    NSString *identifier=[url isKindOfClass:NSURL.class] ? [DPEaselStore.shared identifierForURL:url] : nil;
    if(!identifier && [self respondsToSelector:@selector(tryPortableURL:)]) [self tryPortableURL:url];
    if(!DPEasels.on || !identifier || !self.pane) {
        [self.editor removeFromSuperview]; self.editor=nil; self.document=nil; return;
    }
    if(![self.document.identifier isEqual:identifier]) {
        [self.editor removeFromSuperview]; self.editor=nil;
        self.document=[DPEaselStore.shared load:identifier error:nil];
    }
    if(!self.document || self.document.deleted) { [self.editor removeFromSuperview]; self.editor=nil; return; }
    if(!self.editor) {
        self.creatingEditor=YES;
        @try { self.editor=DPEaselEditor(self.document); }
        @finally { self.creatingEditor=NO; }
    }
    if(self.editor.superview!=self.pane) {
        self.editor.frame=self.pane.bounds;
        self.editor.autoresizingMask=NSViewWidthSizable|NSViewHeightSizable;
        [self.pane addSubview:self.editor positioned:NSWindowAbove relativeTo:nil];
        [NSNotificationCenter.defaultCenter postNotificationName:@"DPEaselHostDidMount" object:self.pane.window];
    }
    DPEaselPublishTitle(self);
}
- (void)webContents:(id)contents didStartProvisionalNavigation:(id)navigation { self.provisionalNavigation=YES; [self.titleDelay invalidate]; self.titleDelay=nil; [self.editor removeFromSuperview]; }
- (void)webContents:(id)contents didCommitNavigation:(id)navigation { self.provisionalNavigation=NO; [self refresh]; }
- (void)webContents:(id)contents didFinishNavigation:(id)navigation { self.provisionalNavigation=NO; [self refresh]; }
- (void)webContents:(id)contents didReceiveServerRedirectForProvisionalNavigation:(id)navigation {}
- (void)webContents:(id)contents didFailNavigation:(id)navigation { self.provisionalNavigation=NO; [self refresh]; }
- (void)webContents:(id)contents didFailProvisionalNavigation:(id)navigation withError:(NSError *)error { self.provisionalNavigation=NO; [self refresh]; }
- (void)webContents:(id)contents didStartInPageNavigation:(id)navigation {}
- (void)webContents:(id)contents didFinishInPageNavigation:(id)navigation { [self refresh]; }
@end
static void DPAttach(id self,SEL _cmd,NSView *pane) {
    DPCallOriginal(DPAttach,self,pane);
    DPEaselBindPane(self,pane);
}
static void DPDetach(id self,SEL _cmd,NSView *pane) {
    DPEaselAttachment *attachment=DPEaselAttachmentFor(self,NO);
    if(attachment.pane==pane) {
        [attachment.editor removeFromSuperview]; attachment.editor=nil; attachment.pane=nil;
    }
    DPCallOriginal(DPDetach,self,pane);
}
@implementation DPEaselHost
+ (void)install {
    DPHook(DPDiaWebContents,@selector(attachToPaneHostView:),(IMP)DPAttach);
    DPHook(DPDiaWebContents,@selector(detachFromPaneHostView:),(IMP)DPDetach);
    DPEaselInstallMetadataHooks();
    [NSNotificationCenter.defaultCenter addObserverForName:@"DPEaselHostAppearanceChanged" object:nil queue:nil usingBlock:^(NSNotification *note){
        for(DPEaselAttachment *attachment in DPAttachments.objectEnumerator) if(attachment.editor==note.object) DPEaselPublishTitle(attachment);
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:DPEaselChanged object:nil queue:nil usingBlock:^(NSNotification *note){
        if(!DPEasels.on) return;
        for(id contents in DPAttachments.keyEnumerator) {
            DPEaselAttachment *attachment=DPEaselAttachmentFor(contents,NO);
            if(attachment.document!=note.object) continue;
            [attachment refresh];
        }
    }];
}
+ (void)finishEditingDocument:(DPEaselDocument *)document {
    for(DPEaselAttachment *attachment in DPAttachments.objectEnumerator)
        if(attachment.document==document && [attachment.editor isKindOfClass:DPEaselEditorSurface.class]) [((DPEaselEditorSurface *)attachment.editor).canvas endText];
}
+ (void)finishEditing {
    for(DPEaselAttachment *attachment in DPAttachments.objectEnumerator)
        if([attachment.editor isKindOfClass:DPEaselEditorSurface.class]) {
            DPEaselCanvas *canvas=((DPEaselEditorSurface *)attachment.editor).canvas; [canvas endText]; [canvas cancelImageImport];
        }
}
+ (void)refresh { for(id contents in DPAttachments.keyEnumerator) [DPEaselAttachmentFor(contents,YES) refresh]; }
@end
