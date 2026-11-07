#import "GrainSettings.h"

static NSString *const DPGrainAmountKey = @"sidebarGrainAmount";
static NSString *const DPGrainSoftnessKey = @"sidebarGrainSoftness";
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

NSInteger DPGrainAmount(void) { return DPGrainSetting(DPGrainAmountKey, 100); }
NSInteger DPGrainSoftness(void) { return DPGrainSetting(DPGrainSoftnessKey, 0); }

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
    NSUInteger index = [DPGrainMaterialKeys() indexOfObject:DPChoice(&DPSidebarGrain)];
    if (index == NSNotFound) index = [DPGrainMaterialKeys() indexOfObject:@"sand"];
    [self.material selectItemAtIndex:index];
    self.amount.integerValue = DPGrainAmount();
    self.softness.integerValue = DPGrainSoftness();
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

- (void)changeMaterial:(NSPopUpButton *)sender {
    NSInteger index = sender.indexOfSelectedItem;
    if (index < 0 || (NSUInteger)index >= DPGrainMaterialKeys().count) return;
    DPSetChoice(&DPSidebarGrain, DPGrainMaterialKeys()[index]);
    [self apply];
}

- (void)resetGrain:(id)sender {
    [DPGrainDefaults() removeObjectForKey:@"sidebarGrainMaterial"];
    [DPGrainDefaults() removeObjectForKey:DPGrainAmountKey];
    [DPGrainDefaults() removeObjectForKey:DPGrainSoftnessKey];
    [self apply];
}

@end

void DPRefreshGrainRows(void) {
    for (DPGrainSettingsRow *row in DPGrainRowsOpen) [row sync];
}

void DPRegisterGrainRow(DPGrainSettingsRow *row) {
    if (!DPGrainRowsOpen) DPGrainRowsOpen = [NSHashTable weakObjectsHashTable];
    [DPGrainRowsOpen addObject:row];
    [row sync];
}
