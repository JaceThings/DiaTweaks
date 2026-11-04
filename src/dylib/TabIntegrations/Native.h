#import "Internal.h"

void DPTabIntegrationFade(NSView *view, float opacity, void (^completion)(void));
BOOL DPIsIntegrationNativePreviewWindow(NSWindow *window);
void DPDetachAllIntegrationHovers(void);
void DPIntegrationHostResize(DPTabIntegrationHost *host, NSSize size);
void DPIntegrationHostShow(DPTabIntegrationHost *host);
BOOL DPIntegrationHostContainsPointer(DPTabIntegrationHost *host);
void DPIntegrationHostClose(DPTabIntegrationHost *host);

@interface DPTabIntegrationHost ()
@property(nonatomic, strong) NSWindow *window;
@property(nonatomic, strong) NSViewController *root;
@property(nonatomic, strong) NSView *background, *slot;
@property(nonatomic, strong) DPTabIntegrationPreview *preview;
@property(nonatomic, weak) NSView *anchor;
@property(nonatomic) NSEdgeInsets shadowInsets;
@property(nonatomic) NSUInteger transition;
@property(nonatomic) BOOL closing, previewStopped;
- (void)stopPreview;
@end
