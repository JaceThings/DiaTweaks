#import "GrainSettings.h"

NSArray<NSView *> *DPGrainRowsForWindow(NSWindow *window) {
    NSPopUpButton *material = [NSPopUpButton new];
    [material addItemsWithTitles:DPGrainMaterialTitles()];
    material.autoenablesItems = NO;
    material.accessibilityLabel = @"Sidebar texture";
    NSStackView *texture = [NSStackView stackViewWithViews:@[[NSTextField labelWithString:@"Texture"], [NSView new], material]];
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
    DPGrainSettingsRow *row = [DPGrainSettingsRow stackViewWithViews:@[texture, heading, swatch, slider, footer, softness, actions]];
    row.orientation = NSUserInterfaceLayoutOrientationVertical;
    row.alignment = NSLayoutAttributeLeading;
    row.spacing = 7;
    for (NSView *view in row.arrangedSubviews)
        [view.widthAnchor constraintEqualToAnchor:row.widthAnchor].active = YES;
    row.material = material;
    material.target = row;
    material.action = @selector(changeMaterial:);
    row.grain = grain;
    row.swatch = swatch;
    row.previewWindow = window;
    row.amountLabel = value;
    row.softnessLabel = softnessValue;
    row.amount = slider;
    row.softness = softness;
    slider.target = softness.target = reset.target = row;
    DPRegisterGrainRow(row);
    return @[row];
}
