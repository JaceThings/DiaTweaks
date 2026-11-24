#import "Library.h"
@interface DPLibraryButton (PointerHover)
- (void)dpLibraryUpdatePointerHover;
@end
@interface DPLibraryQuickTip : NSView @end
@implementation DPLibraryQuickTip
- (NSView *)hitTest:(NSPoint)point { return nil; }
@end
@interface DPLibraryArchiveActionButton : DPLibraryButton
@property NSView *quickTip;
@property NSUInteger tipGeneration;
@property id tipObserver;
@end
static __weak DPLibraryArchiveActionButton *DPActiveTip;
@implementation DPLibraryArchiveActionButton
- (void)clearTip {
    self.tipGeneration++; [self.quickTip removeFromSuperview]; self.quickTip=nil;
    if(self.tipObserver) [NSNotificationCenter.defaultCenter removeObserver:self.tipObserver]; self.tipObserver=nil;
}
- (void)setHovered:(BOOL)hovered { [super setHovered:hovered]; if(!hovered) [self clearTip]; }
- (void)setHidden:(BOOL)hidden { if(hidden) [self clearTip]; [super setHidden:hidden]; }
- (void)dpLibraryUpdatePointerHover { [super dpLibraryUpdatePointerHover]; if(!DPLibraryPointerInside(self)) [self clearTip]; }
- (void)mouseEntered:(NSEvent *)event {
    [super mouseEntered:event]; NSUInteger generation=++self.tipGeneration;
    __weak DPLibraryArchiveActionButton *weak=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,100*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
        DPLibraryArchiveActionButton *button=weak;
        if (!button.hovered || !DPLibraryPointerInside(button) || generation!=button.tipGeneration) return;
        [DPActiveTip clearTip]; DPActiveTip=button;
        NSTextField *label=[NSTextField labelWithString:button.accessibilityLabel ?: @""];
        label.font=[NSFont systemFontOfSize:11 weight:NSFontWeightMedium]; [label sizeToFit];
        NSView *root=button.window.contentView;
        NSRect anchor=[root convertRect:button.bounds fromView:button];
        NSRect frame=NSMakeRect(MAX(4,MIN(NSMidX(anchor)-(NSWidth(label.frame)+16)/2,NSWidth(root.bounds)-NSWidth(label.frame)-20)),
            root.isFlipped ? NSMaxY(anchor)+3 : NSMinY(anchor)-NSHeight(label.frame)-11,NSWidth(label.frame)+16,NSHeight(label.frame)+8);
        DPLibraryQuickTip *tip=[[DPLibraryQuickTip alloc] initWithFrame:frame]; tip.wantsLayer=YES;
        tip.layer.cornerRadius=6; tip.layer.cornerCurve=kCACornerCurveContinuous;
        label.frame=NSMakeRect(8,4,NSWidth(label.frame),NSHeight(label.frame)); [tip addSubview:label];
        [root addSubview:tip positioned:NSWindowAbove relativeTo:nil]; button.quickTip=tip;
        button.tipObserver=[NSNotificationCenter.defaultCenter addObserverForName:NSWindowDidResignKeyNotification object:button.window queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) { [weak clearTip]; }];
        [tip.effectiveAppearance performAsCurrentDrawingAppearance:^{ tip.layer.backgroundColor=NSColor.windowBackgroundColor.CGColor; }];
    });
}
- (void)mouseExited:(NSEvent *)event { [self clearTip]; [super mouseExited:event]; }
- (void)mouseDown:(NSEvent *)event { [self clearTip]; [super mouseDown:event]; }
- (void)viewDidMoveToWindow { [self clearTip]; [super viewDidMoveToWindow]; }
- (void)viewDidMoveToSuperview { [self clearTip]; [super viewDidMoveToSuperview]; }
- (void)dealloc { if(_tipObserver) [NSNotificationCenter.defaultCenter removeObserver:_tipObserver]; [_quickTip removeFromSuperview]; }
@end
