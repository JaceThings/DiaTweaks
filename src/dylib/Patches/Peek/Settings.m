#import "Patches/Peek/Peek.h"

// Peek's sliders on its Settings page, the way the Command bar tunes itself: how dark the page behind gets, and the
// spring the card moves on. Each is stored as the value it means, shown as a whole number.
static NSString *const DPPeekDarknessKey = @"peekDarkness", *const DPPeekSpeedKey = @"peekSpeed", *const DPPeekBounceKey = @"peekBounce";

static NSUserDefaults *DPSettings(void) {
    static NSUserDefaults *settings;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return settings;
}

static double DPPeekTuned(NSString *key) {
    id value = [DPSettings() objectForKey:key];
    if (value) return [value doubleValue];
    return [@{ DPPeekDarknessKey : @0.35, DPPeekSpeedKey : @1, DPPeekBounceKey : @0 }[key] doubleValue];
}

double DPPeekDarkness(void) { return DPPeekTuned(DPPeekDarknessKey); }
double DPPeekResponse(void) { return 0.24 / MAX(0.1, DPPeekTuned(DPPeekSpeedKey)); }  // 100% is iOS's 0.24 s.
double DPPeekBounce(void) { return DPPeekTuned(DPPeekBounceKey); }

static void DPPeekApplyDarkness(void) {
    for (NSWindow *window in NSApp.windows)
        DPPeekCardIn(window).blur.layer.backgroundColor = [NSColor colorWithWhite:0 alpha:DPPeekDarkness()].CGColor;
}

@interface DPPeekTuneRow : NSStackView <NSTextFieldDelegate>
@property (copy) NSString *key;
@property double scale;
@property NSSlider *slider;
@property NSTextField *field;
@end

@implementation DPPeekTuneRow
- (void)tune:(NSControl *)control {
    double shown = round(MIN(MAX(control.doubleValue, self.slider.minValue), self.slider.maxValue));
    self.slider.doubleValue = shown;
    self.field.doubleValue = shown;
    [DPSettings() setDouble:shown / self.scale forKey:self.key];
    DPPeekApplyDarkness();
}

// ↑ and ↓ step the number by 1, or by 10 with Shift.
- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    NSNumber *step = @{ @"moveUp:" : @1, @"moveDown:" : @-1, @"moveUpAndModifySelection:" : @10, @"moveDownAndModifySelection:" : @-10 }[NSStringFromSelector(command)];
    if (!step) return NO;
    self.field.doubleValue = textView.string.doubleValue + step.doubleValue;
    [self tune:self.field];
    [textView selectAll:nil];
    return YES;
}
@end

static NSView *DPPeekSlider(NSString *title, NSString *key, double min, double max, double scale, NSString *unit) {
    double shown = round(DPPeekTuned(key) * scale);
    NSSlider *slider = [NSSlider sliderWithValue:shown minValue:min maxValue:max target:nil action:@selector(tune:)];
    [slider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSNumberFormatter *whole = [NSNumberFormatter new];
    whole.maximumFractionDigits = 0;
    NSTextField *field = [NSTextField textFieldWithString:@""];
    field.formatter = whole;
    field.doubleValue = shown;
    field.alignment = NSTextAlignmentRight;
    field.action = @selector(tune:);
    [field.widthAnchor constraintEqualToConstant:44].active = YES;
    NSStackView *controls = [NSStackView stackViewWithViews:@[ slider, field, [NSTextField labelWithString:unit] ]];
    NSTextField *label = [NSTextField labelWithString:title];
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

    DPPeekTuneRow *row = [DPPeekTuneRow stackViewWithViews:@[ label, controls ]];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    [controls.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    row.key = key;
    row.scale = scale;
    row.slider = slider;
    row.field = field;
    slider.target = field.target = field.delegate = row;
    return row;
}

NSArray<NSView *> *DPPeekSettingsRows(void) {
    return @[
        DPPeekSlider(@"Darken the page behind", DPPeekDarknessKey, 0, 100, 100, @"%"),
        DPPeekSlider(@"Speed", DPPeekSpeedKey, 25, 300, 100, @"%"),
        DPPeekSlider(@"Bounce", DPPeekBounceKey, 0, 60, 100, @"%"),
    ];
}
