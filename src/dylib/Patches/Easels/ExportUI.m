#import "Canvas.h"
#import "Portable.h"
@interface DPEaselExportController : NSViewController
@property(weak) DPEaselEditorSurface *surface;
@property NSButton *editableOption,*previewOption;
@property BOOL editable;
@property NSButton *exportButton,*shareButton;
@end
@implementation DPEaselExportController
- (void)loadView {
    self.view=[[NSView alloc] initWithFrame:NSMakeRect(0,0,340,300)];
    NSTextField *title=[NSTextField labelWithString:@"Export or Share Easel"]; title.font=[NSFont systemFontOfSize:17 weight:NSFontWeightSemibold]; title.frame=NSMakeRect(20,254,300,24); [self.view addSubview:title];
    NSArray *titles=@[@"Editable copy",@"Preview only"];
    NSArray *details=@[@"Includes images and drawing data. The recipient can import and edit their own copy in DiaTweaks.",@"A self-contained web page anyone can view. Drawing data and editing controls are excluded."];
    for(NSUInteger i=0;i<2;i++) {
        CGFloat y=218-i*88;
        NSButton *option=[NSButton radioButtonWithTitle:titles[i] target:self action:@selector(updateMode:)]; option.tag=i;
        option.font=[NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; option.frame=NSMakeRect(20,y,300,22); option.contentTintColor=DPEaselAccent(self.surface); [self.view addSubview:option];
        NSTextField *detail=[NSTextField wrappingLabelWithString:details[i]]; detail.font=[NSFont systemFontOfSize:12]; detail.textColor=NSColor.secondaryLabelColor; detail.frame=NSMakeRect(42,y-52,278,48); [self.view addSubview:detail];
        if(i==0) self.editableOption=option; else self.previewOption=option;
    }
    self.editable=YES; self.editableOption.state=NSControlStateValueOn;
    self.exportButton=[NSButton buttonWithTitle:@"Export File…" target:self action:@selector(exportFile:)]; self.exportButton.bezelStyle=NSBezelStyleRounded; self.exportButton.frame=NSMakeRect(20,20,145,32); self.exportButton.keyEquivalent=@"\r";
    self.exportButton.bezelColor=DPEaselAccent(self.surface); [self.view addSubview:self.exportButton];
    self.shareButton=[NSButton buttonWithTitle:@"Share Copy…" target:self action:@selector(shareFile:)]; self.shareButton.bezelStyle=NSBezelStyleRounded; self.shareButton.frame=NSMakeRect(175,20,145,32); [self.view addSubview:self.shareButton];
}
- (void)updateMode:(NSButton *)sender {
    self.editable=sender.tag==0; self.editableOption.state=self.editable; self.previewOption.state=!self.editable;
}
- (void)shareFile:(id)sender {
    DPEaselEditorSurface *surface=self.surface; BOOL editable=self.editable;
    [surface.exportPopover close]; [surface sharePortableEditable:editable];
}
- (void)exportFile:(id)sender {
    DPEaselEditorSurface *surface=self.surface; NSWindow *window=surface.window;
    BOOL editable=self.editable; [surface.exportPopover close];
    if(!window || window.attachedSheet) return;
    NSSavePanel *panel=NSSavePanel.savePanel; panel.title=@"Export Easel"; panel.canCreateDirectories=YES;
    NSString *name=DPEaselDisplayTitle(surface.canvas.document.title);
    name=[[name componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"/:\n\r"]] componentsJoinedByString:@"-"];
    panel.nameFieldStringValue=[name stringByAppendingString:editable ? @".easel" : @".preview.html"];
    [panel beginSheetModalForWindow:window completionHandler:^(NSModalResponse response){
        if(response!=NSModalResponseOK) return;
        surface.exportButton.enabled=NO;
        [DPEaselStore.shared exportPortable:surface.canvas.document editable:editable toURL:panel.URL completion:^(NSError *error){
            surface.exportButton.enabled=YES;
            if(error) { NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t export Easel"; alert.informativeText=error.localizedDescription; if(!window.attachedSheet) [alert beginSheetModalForWindow:window completionHandler:nil]; }
            else [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[panel.URL]];
        }];
    }];
}
@end
@implementation DPEaselEditorSurface (Export)
- (void)showExport:(NSButton *)sender {
    [self.canvas endText]; [self hideShapeOptions]; [self.palette close];
    DPEaselExportController *controller=DPEaselExportController.new; controller.surface=self;
    self.exportPopover=NSPopover.new; self.exportPopover.behavior=NSPopoverBehaviorTransient; self.exportPopover.contentViewController=controller;
    [self.exportPopover showRelativeToRect:sender.bounds ofView:sender preferredEdge:NSMinYEdge];
}
@end
