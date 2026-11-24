#import "Patches/SidebarLibrary/Library.h"
#import "Portable.h"
#import "HostInternal.h"
static NSMutableSet *DPOpening;
void DPEaselInstallPortableOpen(void) {
    DPOpening=NSMutableSet.new;
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:@"com.diapatches.easel.open" object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
        if(!DPEasels.on || ![note.object isKindOfClass:NSString.class]) return;
        NSURL *url=[NSURL URLWithString:note.object]; NSWindow *window=NSApp.keyWindow ?: NSApp.mainWindow;
        if(!url.isFileURL || ![url.pathExtension.lowercaseString isEqual:@"easel"] || !DPEaselCanCreate(window)) return;
        if([DPOpening containsObject:url.absoluteString]) return;
        [DPOpening addObject:url.absoluteString];
        [DPEaselStore.shared importPortableURL:url profile:DPLibraryContextForWindow(window) completion:^(DPEaselDocument *document,NSError *error){
            [DPOpening removeObject:url.absoluteString];
            [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"com.diapatches.easel.imported" object:url.absoluteString userInfo:nil deliverImmediately:YES];
            if(document) DPEaselOpen(window,document);
            else if(!window.attachedSheet) { NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t import Easel"; alert.informativeText=error.localizedDescription; [alert beginSheetModalForWindow:window completionHandler:nil]; }
        }];
    }];
}

@implementation DPEaselAttachment (Portable)
- (void)tryPortableURL:(NSURL *)url {
    DPEaselAttachment *attachment=self;
    if( [url isKindOfClass:NSURL.class] && [url isFileURL] &&
       ([[url pathExtension].lowercaseString isEqual:@"easel"] || [[url lastPathComponent].lowercaseString hasSuffix:@".easel.html"]) &&
       ![attachment.portableURL isEqual:[url absoluteString]] && DPEaselCanCreate(attachment.pane.window)) {
        attachment.portableURL=[url absoluteString]; __weak DPEaselAttachment *weak=attachment;
        [DPEaselStore.shared importPortableURL:url profile:DPLibraryContextForWindow(attachment.pane.window) completion:^(DPEaselDocument *document,NSError *error){
            DPEaselAttachment *owner=weak;
            if(document && DPEasels.on && owner.pane.window && [[DPEaselRead(owner.contents,@"url") absoluteString] isEqual:owner.portableURL]) DPEaselOpen(owner.pane.window,document);
        }];
    }
}

@end
