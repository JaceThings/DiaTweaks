#import "Peek.h"

@interface DPPeekController : NSObject
@property(nonatomic, strong) id contents;
@property(nonatomic, weak) id sourceContents;
@property(nonatomic, weak) NSView *source;
@property(nonatomic, strong) DPPeekOverlay *overlay;
@property(nonatomic, strong) id keyMonitor;
@property(nonatomic) BOOL closing, dismissing;
- (void)dismiss;
- (void)close;
@end

extern NSMutableSet<DPPeekController *> *DPPeekControllers;
