#import "ListPreview.h"

NS_ASSUME_NONNULL_BEGIN

// Shared snapshot policy for optional conversation-list integrations. The cache is
// mutated only after the complete envelope and each accepted row have been checked.
NSDictionary *DPConversationPresentation(DPTabIntegrationCache *cache, NSDictionary * _Nullable snapshot,
                                        DPTabIntegration *integration, NSTimeInterval receivedAt,
                                        NSTimeInterval now);
void DPConversationSnapshotChanged(DPTabIntegrationPage *page);

// Optional provider adapter for sites whose snapshots use the conversation contract.
// Set providerTitle before the first listContent call; nil displays "Conversations".
@interface DPTabIntegrationConversationPreview : DPTabIntegrationListPreview
@property(nonatomic, copy, nullable) NSString *providerTitle;
@end

NS_ASSUME_NONNULL_END
