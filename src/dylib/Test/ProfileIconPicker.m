#import "Test/Test.h"
#import "Patches/ProfileEmoji/ProfileIcons.h"

NSString *DPVerifyProfileIconPicker(void) {
    DPProfileIconPicker *picker = [DPProfileIconPicker new];
    picker.selectedName = @"briefcase";
    NSSearchField *search = (NSSearchField *)DPFindView(picker.view, ^BOOL(NSView *view) { return [view isKindOfClass:NSSearchField.class]; });
    NSScrollView *scroll = (NSScrollView *)DPFindView(picker.view, ^BOOL(NSView *view) { return [view isKindOfClass:NSScrollView.class]; });
    if (!search || !scroll || scroll.documentView.subviews.count < 70) return @"Profile icon picker did not populate its grid";
    __block NSString *chosen;
    picker.selection = ^(NSString *name) { chosen = name; };
    NSNotification *change = [NSNotification notificationWithName:NSControlTextDidChangeNotification object:search];
    for (NSString *query in @[ @"briefcase", @"hare.fill" ]) {
        search.stringValue = query;
        [picker controlTextDidChange:change];
        NSString *expected = [query isEqual:@"briefcase"] ? @"briefcase.fill" : query;
        NSView *first = scroll.documentView.subviews.firstObject;
        if (scroll.documentView.subviews.count != 1 || ![first isKindOfClass:NSButton.class] || ![first.identifier isEqual:expected]) return @"Profile icon search or exact-name lookup is incorrect";
        NSButton *button = (NSButton *)first;
        if ([query isEqual:@"briefcase"] && button.state != NSControlStateValueOn) return @"Profile icon picker did not highlight the saved selection";
        [button performClick:nil];
        if (![chosen isEqual:expected]) return @"Profile icon picker did not deliver its selection";
        if (!button.image.isTemplate) return @"Profile icon picker image is not monochrome";
    }
    search.stringValue = @"not.a.real.symbol";
    [picker controlTextDidChange:change];
    if (![scroll.documentView.subviews.firstObject isKindOfClass:NSTextField.class]) return @"Profile icon picker did not show an empty-search message";
    return nil;
}
