#import "Address.h"

@implementation DPAddressView (Edit)

- (void)begin {
    if (self.field) {
        [self.window makeFirstResponder:self.field];
        return;
    }
    NSTextField *field = [NSTextField textFieldWithString:self.url.absoluteString ?: self.label.stringValue];
    field.bezeled = NO;
    field.drawsBackground = NO;
    field.focusRingType = NSFocusRingTypeNone;
    field.font = [NSFont systemFontOfSize:13];
    field.usesSingleLineMode = YES;
    field.cell.scrollable = YES;
    field.delegate = self;
    CGFloat height = ceil(field.intrinsicContentSize.height);
    field.frame = NSMakeRect(8, round((NSHeight(self.bounds) - height) / 2), NSWidth(self.bounds) - 16, height);
    field.autoresizingMask = NSViewWidthSizable;
    [self addSubview:field];
    self.field = field;
    self.label.hidden = YES;
    [self refresh];
    // selectText: focuses the field itself; focusing it first would have it end that editing straight away.
    self.beginning = YES;
    [field selectText:nil];
    self.beginning = NO;
}

- (void)end {
    if (!self.field || self.ending) return;
    self.ending = YES;
    [self.field removeFromSuperview];
    self.field = nil;
    self.label.hidden = NO;
    [self.window makeFirstResponder:nil];
    self.ending = NO;
    [self refresh];
}

- (void)controlTextDidEndEditing:(NSNotification *)note {
    if (self.beginning) return;
    BOOL go = [note.userInfo[@"NSTextMovement"] integerValue] == NSTextMovementReturn;
    NSString *typed = self.field.stringValue;
    NSWindow *window = self.window;
    [self end];
    if (go) DPLittleDiaNavigate(window, typed);
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    if (command != @selector(cancelOperation:)) return NO;
    [self end];
    return YES;
}

@end
