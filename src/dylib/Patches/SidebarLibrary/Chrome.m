#import "Library.h"
#import "Patches/SidebarGrain/SidebarGrain.h"
// Reuse the shipped texture renderer and its per-profile preferences.
@interface DPLibraryGrain : DPSidebarGrainView
@property BOOL settingsDirty;
@property NSString *lastSpace;
@property id settingsObserver;
@end
@implementation DPLibraryGrain
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        self.settingsDirty=YES; __weak DPLibraryGrain *weak=self;
        self.settingsObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSUserDefaultsDidChangeNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){ weak.settingsDirty=YES; }];
    } return self;
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:_settingsObserver]; }
- (void)reloadSettings {
    NSString *space=DPLibraryActiveSpace(self.window);
    // The shipped renderer keeps this profile key in its ObjC backing ivar.
    // Library's horizontal host has no native profile-switcher descendants.
    self.lastSpace=space; self.settingsDirty=NO;
    [self setValue:space forKey:@"space"];
    [self setGrainAmount:DPGrainShown(space) ? DPGrainAmount(space) : 0 softness:DPGrainSoftness(space) scale:DPGrainScale(space)];
}
@end
@interface DPLibraryContentChrome : NSView @end
@implementation DPLibraryContentChrome
- (BOOL)isFlipped { return YES; }
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (void)viewDidChangeEffectiveAppearance { [super viewDidChangeEffectiveAppearance]; self.needsDisplay=YES; }
- (void)drawRect:(NSRect)dirty {
    CGFloat radius=MIN(16,MIN(NSWidth(self.bounds),NSHeight(self.bounds))),k=radius*.55228475;
    // Fill the outside of the content curve with the rail's exact material.
    // An unpainted corner exposes a third rectangular shade of the window.
    NSBezierPath *outside=NSBezierPath.bezierPath;
    [outside moveToPoint:NSZeroPoint]; [outside lineToPoint:NSMakePoint(radius,0)];
    [outside curveToPoint:NSMakePoint(0,radius) controlPoint1:NSMakePoint(radius-k,0) controlPoint2:NSMakePoint(0,radius-k)]; [outside closePath];
    [[NSColor.labelColor colorWithAlphaComponent:.045] setFill]; [outside fill];
    NSBezierPath *panel=NSBezierPath.bezierPath;
    [panel moveToPoint:NSMakePoint(radius,0)]; [panel lineToPoint:NSMakePoint(NSWidth(self.bounds),0)];
    [panel lineToPoint:NSMakePoint(NSWidth(self.bounds),NSHeight(self.bounds))]; [panel lineToPoint:NSMakePoint(0,NSHeight(self.bounds))]; [panel lineToPoint:NSMakePoint(0,radius)];
    [panel curveToPoint:NSMakePoint(radius,0) controlPoint1:NSMakePoint(0,radius-k) controlPoint2:NSMakePoint(radius-k,0)]; [panel closePath];
    [[NSColor.controlBackgroundColor colorWithAlphaComponent:.10] setFill]; [panel fill];
}
@end
void DPLibraryUpdateChrome(DPLibraryController *owner) {
    NSView *surface=owner.view;
    surface.layer.cornerRadius=0;
    surface.layer.cornerCurve=kCACornerCurveContinuous;
    surface.layer.maskedCorners=kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
    if(!owner.contentChrome) {
        owner.contentChrome=DPLibraryContentChrome.new; owner.contentChrome.wantsLayer=YES;
        owner.contentChrome.layer.cornerRadius=0; owner.contentChrome.layer.cornerCurve=kCACornerCurveContinuous;
        owner.contentChrome.layer.maskedCorners=kCALayerMinXMinYCorner | kCALayerMinXMaxYCorner;
        [surface addSubview:owner.contentChrome positioned:NSWindowBelow relativeTo:nil];
    }
    owner.contentChrome.hidden=!owner.ownsHost;
    owner.contentChrome.frame=NSMakeRect(88,0,MAX(0,NSWidth(surface.bounds)-88),NSHeight(surface.bounds));
    owner.contentChrome.layer.backgroundColor=nil; owner.contentChrome.needsDisplay=YES;
    DPLibraryGrain *grain=nil;
    for (NSView *v in surface.subviews) if ([v isKindOfClass:DPLibraryGrain.class]) { grain=(id)v; break; }
    if (!owner.ownsHost || !DPSidebarGrain.on) { [grain removeFromSuperview]; return; }
    if (!grain) {
        grain=[[DPLibraryGrain alloc] initWithFrame:surface.bounds]; grain.tracksWindowActivity=YES;
        [surface addSubview:grain positioned:NSWindowBelow relativeTo:nil];
    }
    if(!NSEqualRects(grain.frame,surface.bounds)) grain.frame=surface.bounds;
    if(grain.settingsDirty || ![grain.lastSpace isEqual:DPLibraryActiveSpace(owner.window)]) [grain reloadSettings];
}
