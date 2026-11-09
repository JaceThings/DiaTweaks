#import "GrainSettings.h"

static const DPGrainSetting *const DPGrainSettings[] = { &DPGrainAmountSetting, &DPGrainSoftnessSetting, &DPGrainScaleSetting };
static NSHashTable<NSView *> *DPGrainSliders;

@interface DPGrainSliderRow : NSStackView <NSTextFieldDelegate>
@property const DPGrainSetting *setting;
@property NSSlider *slider;
@property NSTextField *field;
@end

@implementation DPGrainSliderRow

- (void)sync {
    self.slider.integerValue = self.field.integerValue = DPGrainValue(self.setting);
}

- (void)tune:(NSControl *)control {
    NSInteger value = MAX(self.setting->min, MIN(self.setting->max, lround(control.doubleValue)));
    [DPGrainDefaults() setInteger:value forKey:self.setting->key];
    [self sync];
    DPRefreshSidebarGrain();
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)textView doCommandBySelector:(SEL)command {
    NSNumber *step = @{ @"moveUp:" : @1, @"moveDown:" : @-1, @"moveUpAndModifySelection:" : @10, @"moveDownAndModifySelection:" : @-10 }[NSStringFromSelector(command)];
    if (!step) return NO;
    self.field.doubleValue = textView.string.doubleValue + step.doubleValue;
    [self tune:self.field];
    [textView selectAll:nil];
    return YES;
}

@end

static NSView *DPGrainSliderRowFor(const DPGrainSetting *setting) {
    DPGrainSliderRow *row = [DPGrainSliderRow new];
    row.setting = setting;
    row.slider = [NSSlider sliderWithValue:0 minValue:setting->min maxValue:setting->max target:row action:@selector(tune:)];
    [row.slider setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    NSNumberFormatter *whole = [NSNumberFormatter new];
    whole.maximumFractionDigits = 0;
    row.field = [NSTextField textFieldWithString:@""];
    row.field.formatter = whole;
    row.field.alignment = NSTextAlignmentRight;
    row.field.target = row.field.delegate = row;
    row.field.action = @selector(tune:);
    [row.field.widthAnchor constraintEqualToConstant:44].active = YES;
    NSStackView *controls = [NSStackView stackViewWithViews:@[ row.slider, row.field, [NSTextField labelWithString:@"%"] ]];
    [row setViews:@[ [NSTextField labelWithString:setting->title], controls ] inGravity:NSStackViewGravityTop];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    [controls.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    [row sync];
    if (!DPGrainSliders) DPGrainSliders = [NSHashTable weakObjectsHashTable];
    [DPGrainSliders addObject:row];
    return row;
}

@interface DPGrainResetRow : NSStackView
@end

@implementation DPGrainResetRow
- (void)reset:(NSButton *)button {
    for (NSUInteger i = 0; i < 3; i++) [DPGrainDefaults() removeObjectForKey:DPGrainSettings[i]->key];
    for (DPGrainSliderRow *row in DPGrainSliders) [row sync];
    DPRefreshSidebarGrain();
}
@end

NSArray<NSView *> *DPGrainRows(void) {
    DPGrainResetRow *reset = [DPGrainResetRow new];
    NSButton *button = [NSButton buttonWithTitle:@"Reset" target:reset action:@selector(reset:)];
    button.controlSize = NSControlSizeSmall;
    [button setContentHuggingPriority:NSLayoutPriorityRequired forOrientation:NSLayoutConstraintOrientationHorizontal];
    button.accessibilityLabel = @"Reset grain settings";
    NSTextField *label = [NSTextField labelWithString:@"Reset Grain, Softness and Scale"];
    [label setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
    reset.distribution = NSStackViewDistributionFill;
    [reset setViews:@[ label, button ] inGravity:NSStackViewGravityLeading];
    NSMutableArray<NSView *> *rows = [NSMutableArray new];
    for (NSUInteger i = 0; i < 3; i++) [rows addObject:DPGrainSliderRowFor(DPGrainSettings[i])];
    [rows addObject:reset];
    return rows;
}
