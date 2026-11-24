#import "Feedback.h"

static char DPTidyRenamePopoverKey;
static char DPTidyTabFeedbackKey;

@interface DPTidyRenameFeedbackController : NSViewController
@property(copy) dispatch_block_t undo;
@end

@implementation DPTidyRenameFeedbackController
- (void)undoRename:(NSButton *)sender {
    dispatch_block_t undo = self.undo;
    self.undo = nil;
    [self.view removeFromSuperview];
    if (undo) dispatch_async(dispatch_get_main_queue(), undo);
}
@end

static NSColor *DPTidySidebarTint(NSView *anchor) {
    NSView *tint = DPFindView(anchor.window.contentView.superview, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaWindowTint) && !view.hiddenOrHasHiddenAncestor && view.layer;
    });
    if (!tint) return nil;
    NSPoint point = [anchor convertPoint:NSMakePoint(NSMidX(anchor.bounds), NSMidY(anchor.bounds)) toView:tint];
    if (!NSPointInRect(point, tint.bounds)) return nil;

    // Sample Dia's own tint, independent of the page behind the confirmation.
    uint8_t pixel[4] = {0};
    CGColorSpaceRef space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context = CGBitmapContextCreate(pixel, 1, 1, 8, 4, space, (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
    CGColorSpaceRelease(space);
    if (!context) return nil;
    CGContextTranslateCTM(context, -floor(point.x), -floor(point.y));
    [tint.layer renderInContext:context];
    CGContextRelease(context);
    if (!pixel[3]) return nil;
    return [NSColor colorWithSRGBRed:(CGFloat)pixel[0] / pixel[3] green:(CGFloat)pixel[1] / pixel[3]
        blue:(CGFloat)pixel[2] / pixel[3] alpha:1];
}

static void DPTidyPresentTabFeedback(NSView *anchor, NSViewController *controller, NSColor *tint) {
    NSWindow *owner = anchor.window;
    // Dia relayers the page and sidebar during a move. Keep feedback above
    // that content on the window's frame, with a separate lifetime per rename.
    NSView *root = owner.contentView.superview ?: owner.contentView;
    if (!owner.isKeyWindow || !root || ![anchor isDescendantOf:root]) return;
    NSMutableArray<NSViewController *> *feedback = DPGet(owner, &DPTidyTabFeedbackKey);
    if (!feedback) {
        feedback = [NSMutableArray new];
        DPSet(owner, &DPTidyTabFeedbackKey, feedback);
    }
    NSView *content = controller.view;
    NSRect frame = content.frame;
    NSRect target = [root convertRect:anchor.bounds fromView:anchor];
    NSRect bounds = root.bounds;
    frame.origin.x = NSMaxX(target) + 8;
    if (NSMaxX(frame) > NSMaxX(bounds)) frame.origin.x = NSMinX(target) - NSWidth(frame) - 8;
    frame.origin.x = MAX(NSMinX(bounds), frame.origin.x);
    frame.origin.y = MAX(NSMinY(bounds), MIN(NSMaxY(bounds) - NSHeight(frame), NSMidY(target) - NSHeight(frame) / 2));
    for (NSViewController *active in feedback) {
        if (active.view.superview != root || !NSIntersectsRect(frame, active.view.frame)) continue;
        CGFloat above = NSMaxY(active.view.frame) + 6;
        CGFloat below = NSMinY(active.view.frame) - NSHeight(frame) - 6;
        frame.origin.y = above + NSHeight(frame) <= NSMaxY(bounds) ? above : MAX(NSMinY(bounds), below);
    }
    NSView *card;
    if (@available(macOS 26.0, *)) {
        NSGlassEffectView *glass = [[NSGlassEffectView alloc] initWithFrame:frame];
        glass.cornerRadius = 20;
        glass.tintColor = [tint colorWithAlphaComponent:0.18];
        glass.contentView = content;
        card = glass;
    } else {
        NSVisualEffectView *material = [[NSVisualEffectView alloc] initWithFrame:frame];
        material.material = NSVisualEffectMaterialPopover;
        material.blendingMode = NSVisualEffectBlendingModeWithinWindow;
        material.wantsLayer = YES;
        material.layer.cornerRadius = 16;
        material.layer.masksToBounds = YES;
        [material addSubview:content];
        card = material;
    }
    controller.view = card;
    [feedback addObject:controller];
    [root addSubview:card positioned:NSWindowAbove relativeTo:nil];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 4 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [card removeFromSuperview];
        [feedback removeObjectIdenticalTo:controller];
    });
}

static BOOL DPTidyShowRename(NSView *button, NSString *previousName, NSString *name, dispatch_block_t undo) {
    if (!button.window || button.hiddenOrHasHiddenAncestor || NSIsEmptyRect(button.bounds)) return NO;

    [DPGet(button, &DPTidyRenamePopoverKey) close];
    DPTidyRenameFeedbackController *controller = [DPTidyRenameFeedbackController new];
    controller.undo = undo;
    NSString *caption = undo ? @"Tab renamed to" : @"Download renamed to";
    NSTextField *message = [NSTextField labelWithString:caption];
    message.font = [NSFont systemFontOfSize:11];
    message.textColor = NSColor.secondaryLabelColor;

    NSTextField *renamed = [NSTextField wrappingLabelWithString:name];
    renamed.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    renamed.maximumNumberOfLines = 2;
    renamed.lineBreakMode = NSLineBreakByTruncatingMiddle;
    NSTextField *original = [NSTextField labelWithAttributedString:
        [[NSAttributedString alloc] initWithString:previousName attributes:@{
            NSForegroundColorAttributeName: NSColor.secondaryLabelColor,
            NSFontAttributeName: [NSFont systemFontOfSize:11],
            NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)
        }]];
    original.lineBreakMode = NSLineBreakByTruncatingMiddle;

    NSView *heading = message;
    NSColor *tint = undo ? DPTidySidebarTint(button) : nil;
    if (undo) {
        NSButton *undoButton = [NSButton buttonWithTitle:@"Undo" target:controller action:@selector(undoRename:)];
        undoButton.bezelStyle = NSBezelStyleRounded;
        if (@available(macOS 26.0, *)) {
            undoButton.bezelStyle = NSBezelStyleGlass;
            undoButton.borderShape = NSControlBorderShapeCapsule;
        }
        undoButton.bezelColor = tint ?: NSColor.controlAccentColor;
        undoButton.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
        [undoButton.widthAnchor constraintGreaterThanOrEqualToConstant:58].active = YES;
        [undoButton setAccessibilityLabel:@"Undo tab rename"];
        [undoButton setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
        NSStackView *header = [NSStackView stackViewWithViews:@[message, undoButton]];
        header.spacing = 12;
        header.alignment = NSLayoutAttributeFirstBaseline;
        heading = header;
    }
    NSStackView *lines = [NSStackView stackViewWithViews:@[heading, renamed, original]];
    lines.orientation = NSUserInterfaceLayoutOrientationVertical;
    lines.alignment = NSLayoutAttributeLeading;
    lines.spacing = 4;

    lines.translatesAutoresizingMaskIntoConstraints = NO;
    CGFloat width = 248;
    renamed.preferredMaxLayoutWidth = width - 24;
    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, 84)];
    [content addSubview:lines];
    [NSLayoutConstraint activateConstraints:@[
        [content.widthAnchor constraintEqualToConstant:width],
        [lines.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:12],
        [lines.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-12],
        [lines.topAnchor constraintEqualToAnchor:content.topAnchor constant:10],
        [lines.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-10]
    ]];
    controller.view = content;

    if (undo) {
        DPTidyPresentTabFeedback(button, controller, tint);
        if (DPIsKind(button, DPDiaPinnedTab)) DPTidyAnimateTitle(renamed, previousName);
        NSAccessibilityPostNotificationWithUserInfo(button, NSAccessibilityAnnouncementRequestedNotification,
            @{NSAccessibilityAnnouncementKey: [NSString stringWithFormat:@"%@ %@", caption, name]});
        return YES;
    }

    NSPopover *popover = [NSPopover new];
    popover.behavior = NSPopoverBehaviorTransient;
    popover.animates = !NSWorkspace.sharedWorkspace.accessibilityDisplayShouldReduceMotion;
    popover.contentViewController = controller;
    popover.contentSize = content.frame.size;
    DPSet(button, &DPTidyRenamePopoverKey, popover);
    NSRect anchor = NSInsetRect(button.bounds, -3, -4);
    NSRectEdge bottom = button.isFlipped ? NSRectEdgeMaxY : NSRectEdgeMinY;
    [popover showRelativeToRect:anchor ofView:button preferredEdge:bottom];
    NSAccessibilityPostNotificationWithUserInfo(button, NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey: [NSString stringWithFormat:@"%@ %@", caption, name]});
    __weak NSView *weakButton = button;
    __weak NSPopover *weakPopover = popover;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 7 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        NSView *anchorView = weakButton;
        NSPopover *shown = weakPopover;
        if (!shown || DPGet(anchorView, &DPTidyRenamePopoverKey) != shown) return;
        [shown close];
        DPSet(anchorView, &DPTidyRenamePopoverKey, nil);
    });
    return YES;
}

BOOL DPTidyShowDownloadRename(NSView *button, NSString *previousName, NSString *name) {
    return DPTidyShowRename(button, previousName, name, nil);
}

void DPTidyShowTabRename(NSView *tab, NSString *previousName, NSString *name, dispatch_block_t undo) {
    DPTidyShowRename(tab, previousName, name, undo);
}
