#import "StdPatch/StdPatch.h"

#define DPVerticalSidebarRoot "_TtC10TabSidebar15SidebarRootView"
extern DPPatch DPHideVerticalTabGlow;
BOOL DPIsVerticalTab(NSView *shape);
id DPTabDecoration(NSView *shape, const char *name);
BOOL DPHasTabOverride(id part);
void DPHideTabDecoration(id part, NSView *shape);
void DPRestoreTabDecoration(id part);
void DPRestoreTabDecorations(void);
void DPInstallTabDecorations(void);
void DPFlattenTabMaterial(NSView *view, NSView *shape);
NSString *DPVerifyFlatTabMaterial(NSView *shape, BOOL on);
void DPInstallFlatTabMaterial(void);
void DPStyleUniformTabBorder(NSView *shape);
void DPRestoreTabBorder(NSView *shape);
void DPRestoreTabBorders(void);
NSString *DPVerifyUniformTabBorder(NSView *shape, BOOL on);
