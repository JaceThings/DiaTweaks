#import "Canvas.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
@implementation DPEaselEditorSurface (Tools)
- (void)refreshTools {
    DPEaselStyleColorWell(self.colorWell);
    self.exportButton.contentTintColor=DPEaselAccent(self);
    for(NSButton *button in self.buttons) {
        button.state=[button.identifier isEqual:self.canvas.tool] ? NSControlStateValueOn : NSControlStateValueOff;
        button.contentTintColor=button.state ? DPEaselAccent(self) : NSColor.secondaryLabelColor;
    }
    NSDictionary *colored=nil;
    if(self.canvas.selection.count==1) for(NSDictionary *object in self.canvas.document.objects)
        if([self.canvas.selection containsObject:object[@"id"]] && DPEaselObjectCanColor(object)) { colored=object; break; }
    self.colorButton.contentTintColor=colored ? DPEaselObjectColor(colored) : DPEaselObjectColor(@{@"color":self.canvas.color ?: @[@0,@0,@0,@1],@"colorAppearance":self.canvas.colorAppearance ?: @""});
    self.colorButton.toolTip=colored ? @"Object and drawing color" : @"Color for the next drawing";
    [self updateContextTools];
    [self updateShapeOptions];
}
- (void)chooseTool:(NSButton *)button {
    if([button.identifier isEqual:@"image"]) { [self chooseImage:button]; return; }
    [self.canvas selectTool:button.identifier];
}
- (void)chooseImage:(id)sender {
    if(!self.window || self.window.attachedSheet) return;
    NSOpenPanel *panel=NSOpenPanel.openPanel; panel.canChooseDirectories=NO; panel.allowsMultipleSelection=NO;
    panel.allowedContentTypes=@[[NSClassFromString(@"UTType") typeWithIdentifier:@"public.png"],
        [NSClassFromString(@"UTType") typeWithIdentifier:@"public.jpeg"],[NSClassFromString(@"UTType") typeWithIdentifier:@"com.compuserve.gif"]];
    panel.prompt=@"Choose Image";
    NSUInteger generation=++self.canvas.importGeneration;
    __weak DPEaselEditorSurface *weak=self;
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        DPEaselEditorSurface *surface=weak; if(!surface.superview) return;
        if(result!=NSModalResponseOK) { [surface refreshTools]; [surface.window makeFirstResponder:surface.canvas]; return; }
        DPEaselDocument *document=surface.canvas.document;
        [DPEaselStore.shared importImage:panel.URL document:document completion:^(NSString *asset,NSSize size,NSError *error) {
            DPEaselEditorSurface *target=weak;
            if(!target) { if(asset) [DPEaselStore.shared discardUnplacedAsset:asset document:document]; return; }
            [target completeImageImport:asset size:size error:error document:document generation:generation];
        }];
    }];
}
@end
