#import "sidebar-grain-render.h"
#import <objc/message.h>

DPPatch DPSidebarGrain;
NSHashTable<NSView *> *DPGrainSidebars;
NSString *DPTestTexture = @"grain";
NSString *DPChoice(DPPatch *patch) { return DPTestTexture; }
void DPSetChoice(DPPatch *patch, NSString *choice) { DPTestTexture = choice; }
void DPRefreshSidebarGrain(void) {}

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
    assert(DPGrainAmount() == 100 && DPGrainSoftness() == 0);
    NSUInteger renders = 0;
    for (NSString *name in @[NSAppearanceNameAqua, NSAppearanceNameDarkAqua]) {
        NSAppearance *appearance = [NSAppearance appearanceNamed:name];
        NSColor *fallback = DPGrainPreviewColor(nil, appearance);
        assert(fallback && fallback.alphaComponent == 1);
        for (NSString *texture in DPGrainMaterialKeys()) {
            DPTestTexture = texture;
            assert(DPGrainAmount() == 100 && DPGrainSoftness() == 0);
            for (NSNumber *amount in @[@0, @50, @100]) {
                double contrast[3];
                for (NSUInteger s = 0; s < 3; s++) {
                    contrast[s] = DPTestTextureContrast(appearance, texture, amount.doubleValue, s * 50);
                    renders++;
                }
                if (amount.doubleValue == 0) {
                    for (NSUInteger s = 0; s < 3; s++) assert(contrast[s] < .00001);
                } else {
                    if (!(contrast[0] > 0 && contrast[1] < contrast[0] && contrast[2] < contrast[1] && contrast[2] < contrast[0] * .7)) {
                        fprintf(stderr, "%s %s amount %.0f: softness contrasts %.6f %.6f %.6f\n", name.UTF8String, texture.UTF8String, amount.doubleValue, contrast[0], contrast[1], contrast[2]);
                    }
                    assert(contrast[0] > 0 && contrast[1] < contrast[0]);
                    assert(contrast[2] < contrast[1] && contrast[2] < contrast[0] * .7);
                }
            }
        }
        DPTestTextureActivity(appearance);
    }
    [defaults setInteger:61 forKey:@"sidebarGrainAmount"];
    [defaults setInteger:23 forKey:@"sidebarGrainSoftness"];
    for (NSString *texture in DPGrainMaterialKeys()) {
        DPTestTexture = texture; assert(DPGrainAmount() == 61 && DPGrainSoftness() == 23);
    }
    [defaults setInteger:200 forKey:@"sidebarGrainAmount"];
    [defaults setInteger:-50 forKey:@"sidebarGrainSoftness"];
    assert(DPGrainAmount() == 100 && DPGrainSoftness() == 0);
    DPGrainSettingsRow *row = (id)DPGrainRowsForWindow(nil).firstObject;
    assert(row.material.numberOfItems == 6 && row.arrangedSubviews.count == 7);
    ((void (*)(id, SEL, id))objc_msgSend)(row, NSSelectorFromString(@"resetGrain:"), nil);
    DPTestTexture = @"grain";
    assert(DPGrainAmount() == 100 && DPGrainSoftness() == 0);
    [defaults removePersistentDomainForName:DPTestDomain()];
    printf("PASS: %lu light/dark renders; six textures; amount/softness endpoints; native active-window hooks; previews; defaults/reset; saved settings\n", renders);
} }
