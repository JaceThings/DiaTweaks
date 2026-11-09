#import "sidebar-grain-render.h"

DPPatch DPSidebarGrain;
NSString *DPTestTexture = @"grain";
NSString *DPChoice(DPPatch *patch) { return DPTestTexture; }
void DPSetChoice(DPPatch *patch, NSString *choice) { DPTestTexture = choice; }

static NSString *DPTestDomain(void) {
    return [NSString stringWithFormat:@"com.diapatches.grain-test.%d", getpid()];
}

@interface NSUserDefaults (DPGrainFixture)
- (instancetype)dp_grainTestSuite:(NSString *)suite;
@end
@implementation NSUserDefaults (DPGrainFixture)
- (instancetype)dp_grainTestSuite:(NSString *)suite {
    return [self dp_grainTestSuite:[suite isEqual:@"com.diapatches"] ? DPTestDomain() : suite];
}
@end

int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    method_exchangeImplementations(class_getInstanceMethod(NSUserDefaults.class, @selector(initWithSuiteName:)),
        class_getInstanceMethod(NSUserDefaults.class, @selector(dp_grainTestSuite:)));
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    [defaults removePersistentDomainForName:DPTestDomain()];
    DPTestTextureHosts();
    assert(DPGrainAmount() == 50 && DPGrainSoftness() == 0 && DPGrainScale() == 100);
    NSUInteger renders = 0;
    for (NSString *name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
        NSAppearance *appearance = [NSAppearance appearanceNamed:name];
        double loudest = 0, quietest = 1;
        for (NSString *texture in DPGrainMaterialKeys()) {
            DPTestTexture = texture;
            for (NSNumber *softness in @[@0, @50, @100]) {
                for (NSNumber *scale in @[@50, @100, @300]) {
                    double none = DPTestTextureContrast(appearance, texture, 0, softness.doubleValue, scale.doubleValue);
                    double half = DPTestTextureContrast(appearance, texture, 50, softness.doubleValue, scale.doubleValue);
                    double full = DPTestTextureContrast(appearance, texture, 100, softness.doubleValue, scale.doubleValue);
                    renders += 3;
                    assert(none < .00001 && half > 0 && full > half * 1.7 && full < half * 2.3);
                    // Full is clearly visible on every texture, at every softness and scale.
                    assert(full > .03);
                    if (![texture isEqual:@"fine"]) { loudest = MAX(loudest, full); quietest = MIN(quietest, full); }
                }
            }
        }
        assert(loudest < quietest * 1.4);
        DPTestTextureActivity(appearance);
    }
    for (NSString *texture in @[@"sand", @"fine"]) {
        size_t side = CGImageGetWidth(DPGrainAppearanceTile(texture, NO, NO, 100));
        for (NSNumber *scale in @[@50, @150, @300]) {
            assert(CGImageGetWidth(DPGrainAppearanceTile(texture, NO, NO, scale.integerValue)) == side * (size_t)scale.integerValue / 100);
            assert(CGImageGetWidth(DPGrainAppearanceTile(texture, YES, YES, scale.integerValue)) == side * (size_t)scale.integerValue / 100);
        }
    }
    [defaults setInteger:61 forKey:@"sidebarGrainAmount"];
    [defaults setInteger:23 forKey:@"sidebarGrainSoftness"];
    [defaults setInteger:170 forKey:@"sidebarGrainScale"];
    for (NSString *texture in DPGrainMaterialKeys()) {
        DPTestTexture = texture; assert(DPGrainAmount() == 61 && DPGrainSoftness() == 23 && DPGrainScale() == 170);
    }
    [defaults setInteger:200 forKey:@"sidebarGrainAmount"];
    [defaults setInteger:-50 forKey:@"sidebarGrainSoftness"];
    [defaults setInteger:20 forKey:@"sidebarGrainScale"];
    assert(DPGrainAmount() == 100 && DPGrainSoftness() == 0 && DPGrainScale() == 50);
    [defaults setInteger:900 forKey:@"sidebarGrainScale"];
    assert(DPGrainScale() == 300);
    [defaults setInteger:61 forKey:@"sidebarGrainAmount"];
    [defaults setInteger:23 forKey:@"sidebarGrainSoftness"];
    [defaults setInteger:170 forKey:@"sidebarGrainScale"];
    NSArray<NSView *> *rows = DPGrainRows();
    assert(rows.count == 4 && DPGrainTextureMenu().numberOfItems == 6);
    NSInteger shown[] = {61, 23, 170};
    for (NSUInteger i = 0; i < 3; i++) {
        NSSlider *slider = (id)DPFindView(rows[i], ^BOOL(NSView *view) { return [view isKindOfClass:NSSlider.class]; });
        assert(slider.integerValue == shown[i]);
    }
    NSSlider *scale = (id)DPFindView(rows[2], ^BOOL(NSView *view) { return [view isKindOfClass:NSSlider.class]; });
    assert(scale.minValue == 50 && scale.maxValue == 300);
    scale.integerValue = 220;
    [scale sendAction:scale.action to:scale.target];
    assert(DPGrainScale() == 220);
    NSButton *reset = (id)DPFindView(rows[3], ^BOOL(NSView *view) { return [view isKindOfClass:NSButton.class]; });
    DPTestTexture = @"tweed";
    [reset performClick:nil];
    assert(DPGrainAmount() == 50 && DPGrainSoftness() == 0 && DPGrainScale() == 100 && scale.integerValue == 100);
    assert([DPChoice(&DPSidebarGrain) isEqual:@"tweed"]);
    [defaults removePersistentDomainForName:DPTestDomain()];
    printf("PASS: %lu light/dark renders; six textures at equal contrast across amount, softness and scale; native active-window hooks; settings rows; defaults/reset; saved settings\n", renders);
} }
