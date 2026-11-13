#import "Startup.h"

static BOOL DPIsAccountHeader(NSView *header) {
    NSTextField *title = (NSTextField *)DPFindView(header, ^BOOL(NSView *view) { return [view isKindOfClass:NSTextField.class]; });
    return [title.stringValue isEqual:@"Account"];
}

static void DPHeader_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPHeader_layout, self);
    // The arranged stack contains the heading, Name/Email card, and account options row.
    if (DPIsAccountHeader(self)) self.superview.hidden = YES;
}

void DPSkipAccountSettings(void) {
    DPHook(DPSkipAccountHeader, @selector(layout), (IMP)DPHeader_layout);
}

NSString *DPSkipVerifyAccountSettings(void) {
    for (NSView *header in DPFindViews(DPSkipAccountHeader))
        if (DPIsAccountHeader(header) && !header.isHiddenOrHasHiddenAncestor) return @"Account settings section is visible";
    for (NSView *button in DPFindViews("NSButton"))
        if (DPHasLabel(button, @"More account options") && !button.isHiddenOrHasHiddenAncestor) return @"account options button is visible";
    return nil;
}
