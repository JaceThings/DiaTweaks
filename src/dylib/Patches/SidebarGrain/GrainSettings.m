#import "SidebarGrain.h"

static NSString *const DPGrainAmountKey = @"sidebarGrainAmount";
static NSString *const DPGrainSoftnessKey = @"sidebarGrainSoftness";
static const NSInteger DPDefaultAmount = 50, DPDefaultSoftness = 50;
static NSHashTable *DPGrainRowsOpen;

static NSUserDefaults *DPGrainDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

static NSInteger DPGrainSetting(NSString *key, NSInteger fallback) {
    NSNumber *saved = [DPGrainDefaults() objectForKey:key];
    return [saved isKindOfClass:NSNumber.class] ? MAX(0, MIN(100, saved.integerValue)) : fallback;
}

NSInteger DPGrainAmount(void) { return DPGrainSetting(DPGrainAmountKey, DPDefaultAmount); }
NSInteger DPGrainSoftness(void) { return DPGrainSetting(DPGrainSoftnessKey, DPDefaultSoftness); }

@interface DPGrainSettingsRow : NSStackView
@property DPSidebarGrainView *grain;
@property NSBox *swatch;
@property (weak) NSWindow *previewWindow;
@property NSTextField *amountLabel, *softnessLabel;
@property NSSlider *amount, *softness;
- (void)sync;
@end

@implementation DPGrainSettingsRow

- (void)viewDidMoveToWindow {
    [super viewDidMoveToWindow];
    if (self.window) [self sync];
}

- (void)viewDidChangeEffectiveAppearance {
    [super viewDidChangeEffectiveAppearance];
    [self sync];
}

- (void)sync {
    if (self.swatch)
        self.swatch.fillColor = DPGrainPreviewColor(self.previewWindow, self.effectiveAppearance);
    self.amount.integerValue = DPGrainSetting(DPGrainAmountKey, DPDefaultAmount);
    self.softness.integerValue = DPGrainSetting(DPGrainSoftnessKey, DPDefaultSoftness);
    self.amountLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)self.amount.integerValue];
    self.softnessLabel.stringValue = [NSString stringWithFormat:@"%ld%%", (long)self.softness.integerValue];
    [self.grain setGrainAmount:self.amount.integerValue softness:self.softness.integerValue];
}

- (void)apply {
    for (DPGrainSettingsRow *row in DPGrainRowsOpen) [row sync];
    DPRefreshSidebarGrain();
}

- (void)adjustGrain:(NSSlider *)slider {
    NSString *key = slider == self.amount ? DPGrainAmountKey : DPGrainSoftnessKey;
    [DPGrainDefaults() setInteger:slider.integerValue forKey:key];
    [self apply];
}

- (void)resetGrain:(id)sender {
    [DPGrainDefaults() removeObjectForKey:DPGrainAmountKey];
    [DPGrainDefaults() removeObjectForKey:DPGrainSoftnessKey];
    [self apply];
}

@end

NSArray<NSView *> *DPGrainRowsForWindow(NSWindow *window) {
    NSTextField *label = [NSTextField labelWithString:@"Grain"];
    NSTextField *value = [NSTextField labelWithString:@""];
    value.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    value.textColor = NSColor.secondaryLabelColor;
    value.alignment = NSTextAlignmentRight;
    NSStackView *heading = [NSStackView stackViewWithViews:@[label, [NSView new], value]];

    NSBox *swatch = [NSBox new];
    swatch.boxType = NSBoxCustom;
    swatch.borderWidth = 0;
    swatch.cornerRadius = 10;
    swatch.contentViewMargins = NSZeroSize;
    DPSidebarGrainView *grain = [[DPSidebarGrainView alloc] initWithFrame:swatch.contentView.bounds];
    grain.layer.cornerRadius = swatch.cornerRadius;
    [swatch.contentView addSubview:grain];
    [swatch.heightAnchor constraintEqualToConstant:40].active = YES;

    NSSlider *slider = [NSSlider sliderWithValue:0 minValue:0 maxValue:100 target:nil action:@selector(adjustGrain:)];
    slider.continuous = YES;
    slider.accessibilityLabel = @"Sidebar grain";
    NSSlider *softness = [NSSlider sliderWithValue:0 minValue:0 maxValue:100 target:nil action:@selector(adjustGrain:)];
    softness.continuous = YES;
    softness.accessibilityLabel = @"Grain softness";
    NSButton *reset = [NSButton buttonWithTitle:@"Reset" target:nil action:@selector(resetGrain:)];
    NSTextField *softnessValue = [NSTextField labelWithString:@""];
    softnessValue.font = value.font;
    softnessValue.textColor = value.textColor;
    NSStackView *footer = [NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Softness"], [NSView new], softnessValue]];
    NSStackView *actions = [NSStackView stackViewWithViews:@[[NSView new], reset]];
    DPGrainSettingsRow *row = [DPGrainSettingsRow stackViewWithViews:@[heading, swatch, slider, footer, softness, actions]];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    row.spacing = 7;
    for (NSView *view in row.arrangedSubviews)
        [view.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    row.grain = grain;
    row.swatch = swatch;
    row.previewWindow = window;
    row.amountLabel = value;
    row.softnessLabel = softnessValue;
    row.amount = slider;
    row.softness = softness;
    slider.target = softness.target = reset.target = row;
    if (!DPGrainRowsOpen) DPGrainRowsOpen = [NSHashTable weakObjectsHashTable];
    [DPGrainRowsOpen addObject:row];
    [row sync];
    return @[row];
}
