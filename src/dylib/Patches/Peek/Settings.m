#import "Patches/Peek/Peek.h"

// How dark the page behind a peek is, 0–1, with its own switchless slider on the Peek settings page, the way the
// Command bar tunes its darkness.
static NSString *const DPPeekDarknessKey = @"peekDarkness";

static NSUserDefaults *DPSettings(void) {
    static NSUserDefaults *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return settings;
}

double DPPeekDarkness(void) {
    id value = [DPSettings() objectForKey:DPPeekDarknessKey];
    return value ? [value doubleValue] : 0.35;
}

static void DPPeekApplyDarkness(void) {
    for (NSWindow *window in NSApp.windows)
        DPPeekCardIn(window).blur.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPPeekDarkness()].CGColor;
}

@interface DPPeekTuneRow : NSStackView
@property NSSlider *slider;
@property NSTextField *field;
@end

@implementation DPPeekTuneRow
- (void)tune:(NSControl *)control {
    double shown = round(MIN(MAX(control.doubleValue, 0), self.slider.maxValue));
    self.slider.doubleValue = shown;
    self.field.doubleValue = shown;
    [DPSettings() setDouble:shown / 100.0 forKey:DPPeekDarknessKey];
    DPPeekApplyDarkness();
}
@end

NSArray<NSView *> *DPPeekSettingsRows(void) {
    double shown = round(DPPeekDarkness() * 100);
    NSSlider *slider = [NSSlider sliderWithValue:shown minValue:0 maxValue:100 target:nil action:@selector(tune:)];
    [slider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSNumberFormatter *whole = [NSNumberFormatter new];
    whole.maximumFractionDigits = 0;
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.formatter = whole;
    field.doubleValue = shown;
    field.alignment = NSTextAlignmentRight;
    field.action = @selector(tune:);
    [field.widthAnchor constraintEqualToConstant:44].active = YES;
    NSStackView *controls = [NSStackView stackViewWithViews:@[ slider, field, [NSTextField labelWithString:@"%"] ]];
    NSTextField *label = [NSTextField labelWithString:@"Darken the page behind"];
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    DPPeekTuneRow *row = [DPPeekTuneRow stackViewWithViews:@[ label, controls ]];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    [controls.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    row.slider = slider;
    row.field = field;
    slider.target = field.target = row;
    return @[ row ];
}
