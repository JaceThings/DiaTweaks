#import "SidebarGrain.h"

@interface DPGrainSettingsRow : NSStackView
@property DPSidebarGrainView *grain;
@property NSBox *swatch;
@property (weak) NSWindow *previewWindow;
@property NSTextField *amountLabel, *softnessLabel;
@property NSSlider *amount, *softness;
@property NSPopUpButton *material;
- (void)sync;
@end

void DPRegisterGrainRow(DPGrainSettingsRow *row);
