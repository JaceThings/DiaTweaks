#import "SidebarGrain.h"

typedef struct {
    __unsafe_unretained NSString *key, *title;
    NSInteger min, max, fallback;
} DPGrainSetting;

extern const DPGrainSetting DPGrainAmountSetting, DPGrainSoftnessSetting, DPGrainScaleSetting;

NSUserDefaults *DPGrainDefaults(void);
NSInteger DPGrainValue(const DPGrainSetting *setting);
