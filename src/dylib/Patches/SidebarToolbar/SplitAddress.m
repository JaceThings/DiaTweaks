#import "SidebarToolbar.h"

@implementation DPFieldView
- (BOOL)wantsUpdateLayer { return YES; }
- (void)updateLayer {
    self.layer.backgroundColor = [NSColor.labelColor colorWithAlphaComponent:0.07].CGColor;
    self.layer.cornerRadius = 10;
    self.layer.cornerCurve = kCACornerCurveContinuous;
}
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end

// Dia's Open Command Bar item, found by its shortcut since its title is localized.
void DPOpenCommandBar(void) {
    for (NSMenuItem *menu in NSApp.mainMenu.itemArray)
        for (NSMenuItem *item in menu.submenu.itemArray)
            if ([item.keyEquivalent isEqualToString:@"l"] && (item.keyEquivalentModifierMask & NSEventModifierFlagDeviceIndependentFlagsMask) == NSEventModifierFlagCommand) {
                [NSApp sendAction:item.action to:item.target from:item];
                return;
            }
}

@implementation DPSplitAddress {
    DPFieldView *_field;
    NSTextField *_label;
}

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    _field = [DPFieldView new];
    _label = [NSTextField labelWithString:@""];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_field];
    [_field addSubview:_label];
    return self;
}

- (BOOL)isFlipped { return YES; }

- (void)update {
    NSAttributedString *text = DPBarText(self.bar).textStorage ?: [NSAttributedString new];
    if (![_label.attributedStringValue isEqualToAttributedString:text]) _label.attributedStringValue = text.copy;
    self.needsLayout = YES;
}

- (void)layout {
    [super layout];
    NSView *sidebar = self.superview;
    CGFloat top = NSHeight(DPHeaderRow(sidebar)) + DPHeaderGap(sidebar);
    _field.frame = NSMakeRect(DPDockInset, top, NSWidth(self.bounds) - 2 * DPDockInset, DPDockFieldHeight);
    CGFloat height = ceil(_label.intrinsicContentSize.height);
    _label.frame = NSMakeRect(8, floor((DPDockFieldHeight - height) / 2), NSWidth(_field.bounds) - 16, height);
}

// Only the field takes clicks; the rest of the view lies over the sidebar header.
- (NSView *)hitTest:(NSPoint)point {
    return NSPointInRect([self convertPoint:point fromView:self.superview], _field.frame) ? self : nil;
}

- (void)mouseDown:(NSEvent *)event {}

- (void)mouseUp:(NSEvent *)event {
    if (NSPointInRect([self convertPoint:event.locationInWindow fromView:nil], _field.frame)) DPOpenCommandBar();
}
@end

void DPShowSplitAddress(NSWindow *window, NSView *sidebar, NSView *bar) {
    for (NSView *candidate in DPSidebars) {
        if (candidate.window != window) continue;
        DPSplitAddress *shown = nil;
        for (NSView *sub in candidate.subviews.copy) {
            if (![sub isKindOfClass:DPSplitAddress.class]) continue;
            if (candidate == sidebar && bar) shown = (DPSplitAddress *)sub;
            else [sub removeFromSuperview], candidate.needsLayout = YES;
        }
        if (candidate != sidebar || !bar) continue;
        if (!shown) {
            shown = [DPSplitAddress new];
            [candidate addSubview:shown positioned:NSWindowAbove relativeTo:nil];
            candidate.needsLayout = YES;
        }
        shown.bar = bar;
        [shown update];
    }
}

void DPInstallSplitAddress(void) {
    [NSNotificationCenter.defaultCenter addObserverForName:NSTextStorageDidProcessEditingNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        for (NSView *sidebar in DPSidebars) {
            DPSplitAddress *shown = (DPSplitAddress *)DPSubview(sidebar, class_getName(DPSplitAddress.class));
            if (shown && DPBarText(shown.bar).textStorage == note.object) dispatch_async(dispatch_get_main_queue(), ^{ [shown update]; });
        }
    }];
}
