#import "HostInternal.h"
// Reuse the existing native tab-ID reader. It is independent of Tidy Names' toggle.
NSString *DPEaselIdentifierForTabRow(NSView *row,NSWindow *window);
@interface DPEaselTabMenuTarget : NSObject
@property(weak) NSWindow *window;
@property NSString *identifier;
@property NSMenuItem *original,*replacement;
@property NSMenuItem *closeItem,*deleteItem,*separator;
@property NSString *closeTitle;
@property NSMapTable<NSMenuItem *,NSNumber *> *linkVisibility;
@property NSInteger index;
- (void)rename:(id)sender;
- (void)deleteEasel:(id)sender;
@end
@implementation DPEaselTabMenuTarget
- (void)rename:(id)sender {
    DPEaselDocument *document=[DPEaselStore.shared load:self.identifier error:nil];
    if(document) DPEaselPresentRename(self.window,document);
}
- (void)deleteEasel:(id)sender {
    DPEaselDocument *document=[DPEaselStore.shared load:self.identifier error:nil];
    if(document) DPEaselDeleteFromTab(self.window,document);
}
@end
static NSMutableDictionary *DPMenuTargets;
static void DPConfigureTabMenu(NSMenu *menu,NSView *row) {
    if(!DPEasels.on || !menu || DPMenuTargets[[NSValue valueWithNonretainedObject:menu]]) return;
    NSMenuItem *rename=nil;
    for(NSMenuItem *item in menu.itemArray) {
        NSString *name=[item.title stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" .…"]];
        if(item.enabled && [@[@"Rename",@"Rename Tab",@"Rename Current Tab"] containsObject:name]) { rename=item; break; }
    }
    if(!rename) return;
    NSString *identifier=DPEaselIdentifierForTabRow(row,row.window); if(!identifier) return;
    DPEaselTabMenuTarget *target=DPEaselTabMenuTarget.new; target.window=row.window; target.identifier=identifier;
    target.original=rename; target.index=[menu indexOfItem:rename];
    target.replacement=[[NSMenuItem alloc] initWithTitle:@"Rename Easel…" action:@selector(rename:) keyEquivalent:@""]; target.replacement.target=target;
    DPMenuTargets[[NSValue valueWithNonretainedObject:menu]]=target;
    [menu removeItem:rename]; [menu insertItem:target.replacement atIndex:target.index];
    target.linkVisibility=NSMapTable.strongToStrongObjectsMapTable;
    for(NSMenuItem *item in menu.itemArray) {
        if([item.title isEqual:@"Close"]) { target.closeItem=item; target.closeTitle=item.title; item.title=@"Remove Easel from Sidebar"; }
        if([@[@"Copy Link",@"Copy Link as Markdown"] containsObject:item.title]) { [target.linkVisibility setObject:@(item.hidden) forKey:item]; item.hidden=YES; }
    }
    target.separator=NSMenuItem.separatorItem; [menu addItem:target.separator];
    target.deleteItem=[[NSMenuItem alloc] initWithTitle:@"Delete Easel" action:@selector(deleteEasel:) keyEquivalent:@""];
    target.deleteItem.target=target; [menu addItem:target.deleteItem];
}
static NSMenu *DPRowMenu(NSView *self,SEL _cmd,NSEvent *event) {
    NSMenu *menu=DPCallOriginal(DPRowMenu,self,event);
    DPConfigureTabMenu(menu,self); return menu;
}
void DPEaselInstallTabMenus(void) {
    if(DPMenuTargets) return; DPMenuTargets=NSMutableDictionary.new;
    // Resolve the row before native menu tracking changes NSApp.currentEvent.
    DPHook(DPDiaTabView,@selector(menuForEvent:),(IMP)DPRowMenu);
    DPHook(DPDiaPinnedTab,@selector(menuForEvent:),(IMP)DPRowMenu);
    [NSNotificationCenter.defaultCenter addObserverForName:NSMenuDidEndTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note){
        if(![note.object isKindOfClass:NSMenu.class]) return;
        NSMenu *menu=note.object; NSValue *key=[NSValue valueWithNonretainedObject:menu]; DPEaselTabMenuTarget *target=DPMenuTargets[key]; if(!target) return;
        dispatch_async(dispatch_get_main_queue(),^{
            if(DPMenuTargets[key]!=target) return;
            if([menu.itemArray containsObject:target.replacement]) [menu removeItem:target.replacement];
            if(target.closeItem) target.closeItem.title=target.closeTitle;
            for(NSMenuItem *item in target.linkVisibility.keyEnumerator) item.hidden=[[target.linkVisibility objectForKey:item] boolValue];
            if([menu.itemArray containsObject:target.deleteItem]) [menu removeItem:target.deleteItem];
            if([menu.itemArray containsObject:target.separator]) [menu removeItem:target.separator];
            if(![menu.itemArray containsObject:target.original]) [menu insertItem:target.original atIndex:MIN(target.index,menu.numberOfItems)];
            [DPMenuTargets removeObjectForKey:key];
        });
    }];
}
