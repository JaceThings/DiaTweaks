#import "Canvas.h"
NSArray<NSView *> *DPEaselCursorChrome(DPEaselCanvas *canvas) {
    NSView *parent=canvas.enclosingScrollView.superview;
    if(![parent isKindOfClass:DPEaselEditorSurface.class]) return @[];
    DPEaselEditorSurface *surface=(id)parent; NSMutableArray *views=NSMutableArray.new;
    for(NSView *view in @[surface.toolbar ?: NSView.new,surface.colorWell ?: NSView.new,surface.exportWell ?: NSView.new,surface.contextTools ?: NSView.new,surface.objectColorWell ?: NSView.new,surface.shapeOptions ?: NSView.new])
        if(view.superview && !view.hiddenOrHasHiddenAncestor) [views addObject:view];
    return views;
}
BOOL DPEaselCursorOverChrome(DPEaselCanvas *canvas,NSPoint windowPoint) {
    for(NSView *view in DPEaselCursorChrome(canvas)) if(NSPointInRect([view convertPoint:windowPoint fromView:nil],view.bounds)) return YES;
    return NO;
}
NSArray<NSValue *> *DPEaselCursorRegions(DPEaselCanvas *canvas) {
    NSMutableArray *regions=[NSMutableArray arrayWithObject:[NSValue valueWithRect:canvas.visibleRect]];
    for(NSView *view in DPEaselCursorChrome(canvas)) {
        NSRect cut=[canvas convertRect:view.bounds fromView:view]; NSMutableArray *next=NSMutableArray.new;
        for(NSValue *value in regions) {
            NSRect rect=value.rectValue,overlap=NSIntersectionRect(rect,cut);
            if(NSIsEmptyRect(overlap)) { [next addObject:value]; continue; }
            NSRect pieces[]={NSMakeRect(NSMinX(rect),NSMinY(rect),NSWidth(rect),NSMinY(overlap)-NSMinY(rect)),NSMakeRect(NSMinX(rect),NSMaxY(overlap),NSWidth(rect),NSMaxY(rect)-NSMaxY(overlap)),NSMakeRect(NSMinX(rect),NSMinY(overlap),NSMinX(overlap)-NSMinX(rect),NSHeight(overlap)),NSMakeRect(NSMaxX(overlap),NSMinY(overlap),NSMaxX(rect)-NSMaxX(overlap),NSHeight(overlap))};
            for(NSUInteger i=0;i<4;i++) if(!NSIsEmptyRect(pieces[i])) [next addObject:[NSValue valueWithRect:pieces[i]]];
        }
        regions=next;
    } return regions;
}
