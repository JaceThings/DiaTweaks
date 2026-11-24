#import "Easels.h"
@interface DPEaselMenuTarget : NSObject
@property(weak) NSWindow *window;
- (void)create:(id)sender;
@end
@implementation DPEaselMenuTarget
- (void)create:(id)sender { DPEaselCreate(self.window); }
@end
void DPEaselInstallCreateMenu(void) {
    static NSMutableDictionary<NSValue *,DPEaselMenuTarget *> *targets;
    if(targets) return; targets=NSMutableDictionary.new;
    NSNotificationCenter *center=NSNotificationCenter.defaultCenter;
    [center addObserverForName:NSMenuDidBeginTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSEvent *event=NSApp.currentEvent;
        BOOL context=event.type==NSEventTypeRightMouseDown || (event.type==NSEventTypeLeftMouseDown && (event.modifierFlags&NSEventModifierFlagControl));
        NSWindow *window=event.window;
        if(!context || !DPEaselCanCreate(window) || ![note.object isKindOfClass:NSMenu.class]) return;
        NSMenu *menu=note.object; NSInteger insertion=-1;
        for(NSMenuItem *item in menu.itemArray) {
            if([item.identifier isEqual:@"DiaTweaks.Easels.New"]) return;
            if([item.title hasPrefix:@"New Profile"]) insertion=[menu indexOfItem:item]+1;
        }
        // The sentinel scopes this to Dia's actual sidebar menu; do not add
        // actions to unrelated webpage, object, tab or text-field menus.
        if(insertion<0) return;
        DPEaselMenuTarget *target=DPEaselMenuTarget.new; target.window=window;
        NSMenuItem *item=[[NSMenuItem alloc] initWithTitle:@"New Easel" action:@selector(create:) keyEquivalent:@""];
        item.target=target; item.identifier=@"DiaTweaks.Easels.New";
        item.image=[NSImage imageWithSystemSymbolName:@"pencil.and.outline" accessibilityDescription:nil];
        targets[[NSValue valueWithNonretainedObject:menu]]=target;
        [menu insertItem:item atIndex:insertion];
    }];
    [center addObserverForName:NSMenuDidEndTrackingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        if(![note.object isKindOfClass:NSMenu.class]) return;
        NSMenu *menu=note.object;
        NSValue *key=[NSValue valueWithNonretainedObject:menu]; DPEaselMenuTarget *target=targets[key];
        if(!target) return;
        // AppKit may dispatch the chosen action immediately after tracking ends.
        dispatch_async(dispatch_get_main_queue(),^{
            if(targets[key]!=target) return;
            for(NSMenuItem *item in menu.itemArray) if([item.identifier isEqual:@"DiaTweaks.Easels.New"]) [menu removeItem:item];
            [targets removeObjectForKey:key];
        });
    }];
}
