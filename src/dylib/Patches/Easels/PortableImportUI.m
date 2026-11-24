#import "Patches/SidebarLibrary/Library.h"
#import "Portable.h"
void DPEaselPresentImport(NSWindow *window) {
    if(!DPEaselCanCreate(window) || window.attachedSheet) return;
    NSOpenPanel *panel=NSOpenPanel.openPanel; panel.title=@"Import Easel"; panel.message=@"Choose an editable .easel file. A copy will be added to your Easels."; panel.allowsMultipleSelection=NO;
    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){
        if(response!=NSModalResponseOK) return;
        [DPEaselStore.shared importPortableURL:panel.URL profile:DPLibraryContextForWindow(window) completion:^(DPEaselDocument *document,NSError *error){
            if(document) DPEaselOpen(window,document);
            else { NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t import Easel"; alert.informativeText=error.localizedDescription; [alert beginSheetModalForWindow:window completionHandler:nil]; }
        }];
    }];
}
