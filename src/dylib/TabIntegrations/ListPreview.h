#import "Components.h"

NS_ASSUME_NONNULL_BEGIN

// Reusable, compact AppKit list preview. Override listContent only; lifecycle observation,
// updates, and stop behavior are supplied by DPTabIntegrationPreview.
@interface DPTabIntegrationListPreview : DPTabIntegrationPreview
- (DPTabIntegrationListContent *)listContent;
- (void)update;
@end

NS_ASSUME_NONNULL_END
