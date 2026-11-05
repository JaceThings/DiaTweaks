#import "ListRows.h"
#import "ListPreview.h"

@interface DPTabIntegrationListPreview (DPListRowActions)
- (void)performListAction:(NSButton *)sender;
- (void)activateListItem:(DPTabIntegrationItem *)item;
@end

@interface DPIntegrationListRow : NSView
@property(nonatomic, copy) void (^activate)(void);
@property(nonatomic, strong) NSTrackingArea *hoverArea;
@end
@implementation DPIntegrationListRow
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point {
    NSView *hit = [super hitTest:point];
    if (!hit) return nil;
    NSPoint local = [self convertPoint:point fromView:self.superview];
    for (NSView *child in self.subviews)
        if ([child isKindOfClass:NSButton.class] && NSPointInRect(local, child.frame)) return child;
    return self;
}
- (void)mouseDown:(NSEvent *)event { if (self.activate) self.activate(); }
- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    if (self.hoverArea) [self removeTrackingArea:self.hoverArea];
    self.hoverArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
        options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInActiveApp | NSTrackingInVisibleRect
        owner:self userInfo:nil];
    [self addTrackingArea:self.hoverArea];
}
- (void)mouseEntered:(NSEvent *)event {
    self.wantsLayer = YES;
    self.layer.cornerRadius = 6;
    self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.06].CGColor;
}
- (void)mouseExited:(NSEvent *)event { self.layer.backgroundColor = NSColor.clearColor.CGColor; }
@end

NSView *DPIntegrationListMakeRow(DPTabIntegrationItem *item, DPTabIntegrationListPreview *preview,
                                 BOOL cached, CGFloat height) {
    DPIntegrationListRow *row = [[DPIntegrationListRow alloc] initWithFrame:NSMakeRect(0, 0, 256, height)];
    __weak DPTabIntegrationListPreview *weakPreview = preview;
    row.activate = ^{
        [weakPreview activateListItem:item];
    };
    DPIntegrationListPopulateRow(row, item, preview, cached);
    return row;
}
