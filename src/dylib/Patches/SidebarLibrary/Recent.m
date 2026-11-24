#import "Library.h"
static char DPLibraryRecentCardKey;
@interface DPLibraryRecent : NSVisualEffectView
@property NSTrackingArea *tracking;
@property BOOL menuActive, pickerActive;
@property(copy) NSString *spaceID;
- (void)finishInteraction;
@end
@implementation DPLibraryRecent
- (void)removeFromSuperview {
    NSWindow *window = self.window; [super removeFromSuperview];
    if (window && DPGet(window,&DPLibraryRecentCardKey) == self) DPSet(window,&DPLibraryRecentCardKey,nil);
}
- (BOOL)isFlipped { return YES; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
}
- (void)mouseExited:(NSEvent *)event { if (!self.menuActive && !self.pickerActive) [self removeFromSuperview]; }
- (void)finishInteraction {
    __weak DPLibraryRecent *weak = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,140*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        DPLibraryRecent *card = weak;
        NSPoint point = [card convertPoint:card.window.mouseLocationOutsideOfEventStream fromView:nil];
        if (!card.menuActive && !card.pickerActive && !NSPointInRect(point,card.bounds)) [card removeFromSuperview];
    });
}
@end
@interface DPLibraryRecentFile : NSView <NSDraggingSource,NSMenuDelegate,NSSharingServicePickerDelegate>
@property DPLibraryFile *file;
@property NSTrackingArea *tracking;
@property BOOL hovered;
@property BOOL dragged;
@property(copy) NSString *context;
@property NSSharingServicePicker *picker;
@end
@implementation DPLibraryRecentFile
- (NSView *)hitTest:(NSPoint)point { return [super hitTest:point] ? self : nil; }
- (BOOL)accessibilityPerformPress { [self open:nil]; return YES; }
- (void)updateTrackingAreas {
    [super updateTrackingAreas]; if (self.tracking) [self removeTrackingArea:self.tracking];
    self.tracking = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect owner:self userInfo:nil];
    [self addTrackingArea:self.tracking];
}
- (void)mouseEntered:(NSEvent *)event { self.hovered = YES; self.needsDisplay = YES; }
- (void)mouseExited:(NSEvent *)event { self.hovered = NO; self.needsDisplay = YES; }
- (void)drawRect:(NSRect)rect {
    if (self.hovered) { [[NSColor.labelColor colorWithAlphaComponent:.06] setFill]; [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:8 yRadius:8] fill]; }
}
- (NSURL *)fileURL { return [NSURL fileURLWithPath:self.file.path]; }
- (void)open:(id)sender { [NSWorkspace.sharedWorkspace openURL:self.fileURL]; }
- (void)copy:(id)sender { [NSPasteboard.generalPasteboard clearContents]; [NSPasteboard.generalPasteboard writeObjects:@[self.fileURL]]; }
- (void)reveal:(id)sender { [NSWorkspace.sharedWorkspace activateFileViewerSelectingURLs:@[self.fileURL]]; }
- (void)hide:(id)sender { DPLibraryDissolve(@[self],^{ DPLibraryHideFiles(self.context,@[self.file]); [self.superview removeFromSuperview]; }); }
- (void)share:(id)sender {
    if (!self.window) return;
    [(DPLibraryRecent *)self.superview setPickerActive:YES];
    self.picker = [[NSSharingServicePicker alloc] initWithItems:@[self.fileURL]]; self.picker.delegate = self;
    [self.picker showRelativeToRect:self.bounds ofView:self preferredEdge:NSMaxXEdge];
}
- (NSMenu *)menuForEvent:(NSEvent *)event {
    NSMenu *menu = [NSMenu new]; menu.delegate = self;
    [(DPLibraryRecent *)self.superview setMenuActive:YES];
    NSArray *names = @[@"Open",@"Copy",@"Show in Finder",@"Share…",@"Hide from Library"], *actions = @[@"open:",@"copy:",@"reveal:",@"share:",@"hide:"];
    for (NSUInteger i=0;i<names.count;i++) { NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:names[i] action:NSSelectorFromString(actions[i]) keyEquivalent:@""]; item.target = self; item.representedObject = self; [menu addItem:item]; }
    return menu;
}
- (void)rightMouseDown:(NSEvent *)event { [NSMenu popUpContextMenu:[self menuForEvent:event] withEvent:event forView:self]; }
- (void)menuDidClose:(NSMenu *)menu {
    DPLibraryRecent *card = (id)self.superview; card.menuActive = NO; [card finishInteraction];
}
- (void)sharingServicePicker:(NSSharingServicePicker *)picker didChooseSharingService:(NSSharingService *)service {
    DPLibraryRecent *card = (id)self.superview; card.pickerActive = NO; [card finishInteraction];
}
- (void)mouseDown:(NSEvent *)event {
    self.dragged = NO;
}
- (void)mouseUp:(NSEvent *)event {
    if (!self.dragged && event.clickCount == 1 && NSPointInRect([self convertPoint:event.locationInWindow fromView:nil],self.bounds)) [self open:nil];
}
- (void)mouseDragged:(NSEvent *)event {
    if (![NSFileManager.defaultManager fileExistsAtPath:self.file.path]) return;
    self.dragged = YES;
    NSDraggingItem *item = [[NSDraggingItem alloc] initWithPasteboardWriter:[NSURL fileURLWithPath:self.file.path]];
    [item setDraggingFrame:NSMakeRect(8,8,44,44) contents:[NSWorkspace.sharedWorkspace iconForFile:self.file.path]];
    [self beginDraggingSessionWithItems:@[item] event:event source:self];
}
- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context { return NSDragOperationCopy; }
@end
NSView *DPLibraryRecentView(NSWindow *window) {
    NSString *context = DPLibraryContextForWindow(window);
    NSArray *files = [DPLibraryFiltered(DPLibraryFiles(context),@"",1,NO) filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DPLibraryFile *file,NSDictionary *bindings) { return [NSFileManager.defaultManager fileExistsAtPath:file.path]; }]];
    NSUInteger count = MIN(4,files.count); if (!count) return nil;
    DPLibraryRecent *card = [[DPLibraryRecent alloc] initWithFrame:NSMakeRect(0,0,260,12+count*62)];
    card.spaceID = DPLibraryActiveSpace(window); DPSet(window,&DPLibraryRecentCardKey,card);
    card.material = NSVisualEffectMaterialPopover; card.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    card.state = NSVisualEffectStateFollowsWindowActiveState; card.wantsLayer = YES;
    card.layer.cornerRadius = 12; card.layer.masksToBounds = YES;
    NSRelativeDateTimeFormatter *relative = [NSRelativeDateTimeFormatter new]; relative.unitsStyle = NSRelativeDateTimeFormatterUnitsStyleFull;
    card.layer.borderWidth = 0.5; card.layer.borderColor = [NSColor.labelColor colorWithAlphaComponent:0.14].CGColor;
    for (NSUInteger i=0;i<count;i++) {
        DPLibraryFile *file = files[i];
        DPLibraryRecentFile *row = [[DPLibraryRecentFile alloc] initWithFrame:NSMakeRect(6,6+i*62,248,60)]; row.file = file;
        row.context = context; row.accessibilityElement = YES; row.accessibilityRole = NSAccessibilityButtonRole; row.accessibilityLabel = file.path.lastPathComponent;
        NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(8,8,44,44)];
        icon.image = [NSWorkspace.sharedWorkspace iconForFile:file.path]; icon.imageScaling = NSImageScaleProportionallyUpOrDown;
        [row addSubview:icon];
        if (DPLibraryIsMedia(file)) {
            __weak NSImageView *weakIcon = icon;
            DPLibraryThumbnail([NSURL fileURLWithPath:file.path],^(NSImage *image) { if (image) weakIcon.image = image; });
        }
        NSTextField *name = [NSTextField labelWithString:file.path.lastPathComponent];
        name.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium]; name.frame = NSMakeRect(62,28,174,20);
        name.lineBreakMode = NSLineBreakByTruncatingMiddle; [row addSubview:name];
        NSTextField *date = [NSTextField labelWithString:[relative localizedStringForDate:file.date relativeToDate:NSDate.date]];
        date.textColor = NSColor.secondaryLabelColor; date.font = [NSFont systemFontOfSize:11]; date.frame = NSMakeRect(62,10,174,16);
        [row addSubview:date]; [card addSubview:row]; row.wantsLayer = YES;
        if (!NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion) {
            CABasicAnimation *slide = [CABasicAnimation animationWithKeyPath:@"transform.translation.y"];
            slide.fromValue = @10; slide.toValue = @0; slide.duration = 0.18+i*0.035;
            slide.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
            [row.layer addAnimation:slide forKey:@"recentEntrance"];
        }
    }
    return card;
}

BOOL DPLibraryCanDismissRecent(NSView *view) { DPLibraryRecent *card = (id)view; return !card.menuActive && !card.pickerActive; }
void DPLibraryCheckRecentContext(NSWindow *window) {
    DPLibraryRecent *card = DPGet(window,&DPLibraryRecentCardKey);
    if (card && ![card.spaceID isEqual:DPLibraryActiveSpace(window)]) [card removeFromSuperview];
}

// Dia handles sidebar context clicks before dispatching them to descendant views.
// Claim only clicks inside a visible preview row, before native window routing.
BOOL DPLibraryHandleRecentContextMenu(NSEvent *event) {
    if (event.type != NSEventTypeRightMouseDown &&
        !(event.type == NSEventTypeLeftMouseDown && (event.modifierFlags & NSEventModifierFlagControl))) return NO;
    NSWindow *window = event.window ?: [NSApp windowWithWindowNumber:event.windowNumber];
    DPLibraryRecent *card = DPGet(window,&DPLibraryRecentCardKey);
    if (!card || card.hiddenOrHasHiddenAncestor || !card.superview || card.window!=window || window.attachedSheet || card.alphaValue<.01) return NO;
    NSPoint point = [card convertPoint:event.locationInWindow fromView:nil];
    if (!NSPointInRect(point,card.visibleRect)) return NO;
    NSView *root=window.contentView;
    if(card.superview!=root) return NO;
    // Native vertical-sidebar hit testing can intentionally return its own
    // context surface before looking at overlay descendants. The card is a
    // top-level overlay; inspect only siblings painted above it for occlusion.
    NSPoint rootPoint=[root convertPoint:event.locationInWindow fromView:nil];
    for(NSView *sibling in root.subviews.reverseObjectEnumerator) {
        if(sibling==card) break;
        if(sibling.hiddenOrHasHiddenAncestor || sibling.alphaValue<.01) continue;
        if([sibling hitTest:rootPoint]) return NO;
    }
    for (DPLibraryRecentFile *row in card.subviews) {
        if (![row isKindOfClass:DPLibraryRecentFile.class] || !NSPointInRect(point,row.frame)) continue;
        [row rightMouseDown:event]; return YES;
    }
    return NO;
}
