#import "StdPatch/StdPatch.h"

@interface DPSidebarGrainView : NSView
@property BOOL tracksWindowActivity;
- (void)setGrainAmount:(double)amount softness:(double)softness;
@end

CGImageRef DPFineGrainTile(void);
CGImageRef DPMatteGrainTile(BOOL soft);
NSArray<NSString *> *DPGrainMaterialKeys(void);
NSArray<NSString *> *DPGrainMaterialTitles(void);
BOOL DPIsPatternGrainMaterial(NSString *material);
CGImageRef DPPatternGrainTile(NSString *material, BOOL soft);
CGFloat DPPatternGrainStrength(NSString *material);

NSRect DPGrainHostBounds(NSView *host);

BOOL DPGrainDarkAppearance(NSAppearance *appearance);
CGImageRef DPGrainAppearanceTile(NSString *material, BOOL soft, BOOL dark);
