#import "Canvas.h"
#import "Portable.h"
@interface DPEaselShareSession : NSObject <NSSharingServicePickerDelegate,NSSharingServiceDelegate>
@property DPEaselEditorSurface *surface;
@property NSURL *directory,*file;
@property NSSharingServicePicker *picker;
- (void)finish;
- (void)fail:(NSError *)error;
@end
@implementation DPEaselShareSession
- (void)finish {
    [NSFileManager.defaultManager removeItemAtURL:self.directory error:nil];
    self.picker.delegate=nil; self.picker=nil;
    DPEaselEditorSurface *owner=self.surface; self.surface=nil; owner.exportButton.enabled=YES; owner.sharingSession=nil;
}
- (id<NSSharingServiceDelegate>)sharingServicePicker:(NSSharingServicePicker *)picker delegateForSharingService:(NSSharingService *)service { return self; }
- (void)sharingServicePicker:(NSSharingServicePicker *)picker didChooseSharingService:(NSSharingService *)service { if(!service) [self finish]; }
- (void)sharingService:(NSSharingService *)service didShareItems:(NSArray *)items { [self finish]; }
- (void)sharingService:(NSSharingService *)service didFailToShareItems:(NSArray *)items error:(NSError *)error {
    [self fail:error];
}
- (void)fail:(NSError *)error {
    NSWindow *window=self.surface.window; [self finish];
    if(error.code==NSUserCancelledError) return;
    NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t share Easel"; alert.informativeText=error.localizedDescription;
    if(window && !window.attachedSheet) [alert beginSheetModalForWindow:window completionHandler:nil];
}
@end
@implementation DPEaselEditorSurface (Sharing)
- (void)sharePortableEditable:(BOOL)editable {
    if(self.sharingSession || !self.window) return;
    DPEaselShareSession *session=DPEaselShareSession.new; session.surface=self; self.sharingSession=session;
    session.directory=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[@"DiaTweaks-Easel-Share-" stringByAppendingString:NSUUID.UUID.UUIDString]] isDirectory:YES];
    NSError *error=nil;
    if(![NSFileManager.defaultManager createDirectoryAtURL:session.directory withIntermediateDirectories:YES attributes:nil error:&error]) {
        [session fail:error]; return;
    }
    NSString *name=DPEaselDisplayTitle(self.canvas.document.title);
    name=[[name componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/:\n\r"]] componentsJoinedByString:@"-"];
    session.file=[session.directory URLByAppendingPathComponent:[name stringByAppendingString:editable ? @".easel" : @".preview.html"]];
    self.exportButton.enabled=NO;
    [DPEaselStore.shared exportPortable:self.canvas.document editable:editable toURL:session.file completion:^(NSError *failure){
        if(failure) { [session fail:failure]; return; }
        if(!self.window || self.hiddenOrHasHiddenAncestor) { [session finish]; return; }
        session.picker=[[NSSharingServicePicker alloc] initWithItems:@[session.file]]; session.picker.delegate=session;
        [session.picker showRelativeToRect:self.exportButton.bounds ofView:self.exportButton preferredEdge:NSMinYEdge];
    }];
}
@end
