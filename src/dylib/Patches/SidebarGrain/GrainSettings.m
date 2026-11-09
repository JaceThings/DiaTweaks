#import "GrainSettings.h"

const DPGrainSetting DPGrainAmountSetting = {@"sidebarGrainAmount", @"Grain", 0, 100, 50};
const DPGrainSetting DPGrainSoftnessSetting = {@"sidebarGrainSoftness", @"Softness", 0, 100, 0};
const DPGrainSetting DPGrainScaleSetting = {@"sidebarGrainScale", @"Scale", 50, 300, 100};

NSUserDefaults *DPGrainDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

NSInteger DPGrainValue(const DPGrainSetting *setting) {
    NSNumber *saved = [DPGrainDefaults() objectForKey:setting->key];
    return [saved isKindOfClass:NSNumber.class] ? MAX(setting->min, MIN(setting->max, saved.integerValue)) : setting->fallback;
}

NSInteger DPGrainAmount(void) { return DPGrainValue(&DPGrainAmountSetting); }
NSInteger DPGrainSoftness(void) { return DPGrainValue(&DPGrainSoftnessSetting); }
NSInteger DPGrainScale(void) { return DPGrainValue(&DPGrainScaleSetting); }

NSMenu *DPGrainTextureMenu(void) {
    NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Texture"];
    [DPGrainMaterialTitles() enumerateObjectsUsingBlock:^(NSString *title, NSUInteger i, BOOL *stop) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
        item.representedObject = DPGrainMaterialKeys()[i];
        [menu addItem:item];
    }];
    return menu;
}
