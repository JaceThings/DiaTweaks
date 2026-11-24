#import "Easels.h"
void DPEaselPresentRename(NSWindow *window,DPEaselDocument *document) {
    if(!window || window.attachedSheet || !document || document.deleted) return;
    [DPEaselHost finishEditingDocument:document];
    NSAlert *alert=NSAlert.new; alert.messageText=@"Rename Easel";
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,300,26)];
    field.stringValue=document.title; field.placeholderString=@"Untitled"; field.accessibilityLabel=@"Easel name";
    alert.accessoryView=field; [alert addButtonWithTitle:@"Rename"]; [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){
        if(response!=NSAlertFirstButtonReturn || document.deleted) return;
        [document rename:field.stringValue.length ? field.stringValue : @"Untitled"];
        [DPEaselStore.shared save:document completion:nil];
    }];
    [field selectText:nil];
}
