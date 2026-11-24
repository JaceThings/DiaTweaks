#import "Canvas.h"
@interface DPEaselAccessibleObject : NSAccessibilityElement
@property(weak) DPEaselCanvas *canvas;
@property NSString *identifier;
@end
@implementation DPEaselAccessibleObject
- (BOOL)isAccessibilityElement { return YES; }
- (NSDictionary *)object {
    for(NSDictionary *object in self.canvas.document.objects) if([object[@"id"] isEqual:self.identifier]) return object;
    return nil;
}
- (NSString *)accessibilityLabel {
    NSDictionary *object=self.object;
    return [object[@"type"] isEqual:@"text"] ? object[@"text"] : [object[@"alt"] length] ? object[@"alt"] : [object[@"type"] capitalizedString];
}
- (NSRect)accessibilityFrame {
    NSRect frame=[self.canvas convertRect:DPEaselObjectRect(self.object) toView:nil];
    return [self.canvas.window convertRectToScreen:frame];
}
- (BOOL)accessibilityPerformPress {
    DPEaselCanvas *canvas=self.canvas; if(!self.object || canvas.document.deleted) return NO;
    [canvas endText]; [canvas selectTool:@"select"]; [canvas.selection addObject:self.identifier];
    [canvas scrollRectToVisible:DPEaselObjectRect(self.object)]; canvas.needsDisplay=YES;
    if(canvas.selectionChanged) canvas.selectionChanged(); return YES;
}
- (NSArray *)accessibilityCustomActions {
    __weak DPEaselAccessibleObject *weak=self;
    NSMutableArray *actions=NSMutableArray.new;
    if([self.object[@"type"] isEqual:@"text"]) [actions addObject:[[NSAccessibilityCustomAction alloc] initWithName:@"Edit Text" handler:^BOOL {
        DPEaselAccessibleObject *element=weak; if(![element accessibilityPerformPress]) return NO; [element.canvas beginText:element.object]; return YES;
    }]];
    [actions addObject:[[NSAccessibilityCustomAction alloc] initWithName:@"Delete" handler:^BOOL {
        DPEaselAccessibleObject *element=weak; if(![element accessibilityPerformPress]) return NO; [element.canvas delete:nil]; return YES;
    }]];
    return actions;
}
@end
@implementation DPEaselCanvas (Accessibility)
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityRole { return NSAccessibilityGroupRole; }
- (NSString *)accessibilityLabel { return @"Easel Canvas"; }
- (NSArray *)accessibilityChildren {
    NSMutableArray *children=NSMutableArray.new;
    if(!self.accessibleObjects) self.accessibleObjects=NSMutableDictionary.new;
    NSMutableSet *live=NSMutableSet.new;
    for(NSDictionary *object in self.document.objects) {
        [live addObject:object[@"id"]];
        if([object[@"id"] isEqual:self.textObjectID]) { [children addObject:self.textEditor]; continue; }
        DPEaselAccessibleObject *element=self.accessibleObjects[object[@"id"]];
        if(!element) { element=DPEaselAccessibleObject.new; self.accessibleObjects[object[@"id"]]=element; }
        element.canvas=self; element.identifier=object[@"id"];
        element.accessibilityParent=self; element.accessibilityRole=NSAccessibilityButtonRole;
        element.accessibilityEnabled=YES;
        [children addObject:element];
    }
    for(NSString *identifier in self.accessibleObjects.allKeys) if(![live containsObject:identifier]) [self.accessibleObjects removeObjectForKey:identifier];
    return children;
}
@end
