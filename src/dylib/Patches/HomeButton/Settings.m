#import "HomeButton.h"

// The Home Page field on the patch's Settings page. It saves as you type; the house picks it up on its next click.
@interface DPHomePageRow : NSStackView <NSTextFieldDelegate>
@end

@implementation DPHomePageRow
- (void)controlTextDidChange:(NSNotification *)note {
    DPSetHomePage(((NSTextField *)note.object).stringValue);
}
@end

NSArray<NSView *> *DPHomeButtonRows(void) {
    NSTextField *label = [NSTextField labelWithString:@"Home Page"];
    NSTextField *field = [NSTextField textFieldWithString:DPHomePage()];
    field.placeholderString = @"apple.com";
    [field setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    [field.widthAnchor constraintGreaterThanOrEqualToConstant:220].active = YES;
    DPHomePageRow *row = [DPHomePageRow stackViewWithViews:@[ label, field ]];
    row.distribution = NSStackViewDistributionFill;
    field.delegate = row;
    return @[ row ];
}
