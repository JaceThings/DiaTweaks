#import "ChatGPTPreview.h"

// Website schema/status policy; storage, expiration and context cleanup belong to TabIntegrations.
NSDictionary *DPChatGPTCachePresentation(DPTabIntegrationCache *cache, NSDictionary *snapshot,
                                       NSTimeInterval receivedAt, NSTimeInterval now);
void DPChatGPTSnapshotChanged(DPTabIntegrationPage *page);
NSString *DPChatGPTEmptyMessage(NSString *state, NSTimeInterval elapsed);
