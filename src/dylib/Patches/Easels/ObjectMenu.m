#import "Canvas.h"
@implementation DPEaselCanvas (ObjectMenu)
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSDictionary *hit=[self objectAtPoint:[self convertPoint:event.locationInWindow fromView:nil]];
    if(hit && ![self.selection containsObject:hit[@"id"]]) [self.selection setSet:[NSSet setWithObject:hit[@"id"]]];
    self.needsDisplay=YES; NSMenu *menu=NSMenu.new;
    NSArray *items=@[@[@"Bring to Front",@"bringToFront:"],@[@"Send to Back",@"sendToBack:"],@[@"Delete",@"delete:"],@[],
        @[@"Cut",@"cut:"],@[@"Copy",@"copy:"],@[@"Paste",@"paste:"],@[],@[@"Duplicate",@"duplicate:"],@[@"Add Alt Text…",@"editAltText:"]];
    for(NSArray *entry in items) {
        if(!entry.count) { [menu addItem:NSMenuItem.separatorItem]; continue; }
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:entry[0] action:NSSelectorFromString(entry[1]) keyEquivalent:@""];
        item.target=self; [menu addItem:item];
    }
    if(self.selection.count==1 && [hit[@"type"] isEqual:@"image"] && hit[@"crop"]) {
        [menu addItem:NSMenuItem.separatorItem]; NSMenuItem *reset=[[NSMenuItem alloc] initWithTitle:@"Reset Image Crop" action:@selector(resetImageCrop:) keyEquivalent:@""]; reset.target=self; [menu addItem:reset];
    }
    return menu;
}
- (BOOL)validateMenuItem:(NSMenuItem *)item {
    if(self.document.deleted) return NO;
    if(item.action==@selector(paste:)) return [[NSSet setWithArray:NSPasteboard.generalPasteboard.types] intersectsSet:[NSSet setWithArray:@[NSPasteboardTypeString,NSPasteboardTypePNG,@"com.diatweaks.easels.objects"]]];
    if(item.action==@selector(editAltText:)) return self.selection.count==1;
    return self.selection.count>0;
}
- (void)editAltText:(id)sender {
    if(self.selection.count!=1 || self.window.attachedSheet) return;
    NSDictionary *object=nil; for(NSDictionary *candidate in self.document.objects) if([self.selection containsObject:candidate[@"id"]]) { object=candidate; break; }
    if(!object) return;
    NSAlert *alert=NSAlert.new; alert.messageText=@"Alt Text"; alert.informativeText=@"Describe this object for someone using a screen reader.";
    NSTextField *field=[[NSTextField alloc] initWithFrame:NSMakeRect(0,0,340,56)]; field.stringValue=object[@"alt"] ?: @""; alert.accessoryView=field;
    [alert addButtonWithTitle:@"Save"]; [alert addButtonWithTitle:@"Cancel"];
    NSString *identifier=object[@"id"]; __weak DPEaselCanvas *weak=self;
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response){
        DPEaselCanvas *canvas=weak; if(response!=NSAlertFirstButtonReturn || !canvas || canvas.document.deleted) return;
        NSMutableArray *objects=[canvas.document.objects mutableCopy];
        for(NSUInteger i=0;i<objects.count;i++) if([objects[i][@"id"] isEqual:identifier]) {
            NSMutableDictionary *changed=[objects[i] mutableCopy]; changed[@"alt"]=[field.stringValue substringToIndex:MIN(field.stringValue.length,10000)]; objects[i]=changed; break;
        }
        [canvas commit:objects action:@"Edit Alt Text"];
    }];
}
@end
