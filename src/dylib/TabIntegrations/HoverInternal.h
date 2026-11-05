#import "Native.h"

extern char DPTabIntegrationTrackerKey;
extern __weak id DPTabIntegrationCurrentTracker;
extern NSHashTable *DPTabIntegrationTrackers;

BOOL DPAnyIntegrationEnabled(void);

@interface DPTabIntegrationHoverTracker : NSObject
@property(nonatomic, weak) NSView *anchor;
@property(nonatomic, strong) NSTrackingArea *area;
@property(nonatomic, strong) DPTabIntegrationHost *host;
@property(nonatomic, strong) id tab;
@property(nonatomic) DPTabIntegration *integration;
@property(nonatomic, copy) NSString *tabID;
@property(nonatomic, strong) id eventMonitor;
@property(nonatomic, strong) NSTimer *reveal, *dismiss;
- (BOOL)pointerInside:(NSView *)view;
- (void)show;
- (void)stop;
- (void)close;
- (void)reconcile;
@end
