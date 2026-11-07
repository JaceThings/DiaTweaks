#import "StdPatch/StdPatch.h"

extern DPPatch DPHideActiveTabGlow;
void DPHideTabDecoration(id part);
void DPFlattenTabMaterial(NSView *shape);
NSString *DPVerifyFlatTabMaterial(NSView *shape, BOOL on);
void DPInstallFlatTabMaterial(void);
void DPStyleUniformTabBorder(NSView *shape);
void DPRestoreTabBorders(void);
NSString *DPVerifyUniformTabBorder(NSView *shape, BOOL on);
