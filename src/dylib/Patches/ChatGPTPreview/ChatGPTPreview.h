#import "TabIntegrations/TabIntegrations.h"
#import "TabIntegrations/ListPreview.h"

extern DPPatch DPChatGPTPreview;
extern DPTabIntegration DPChatGPTIntegration;
BOOL DPChatGPTURL(NSString *value);
NSString *DPChatGPTConversationURL(NSString *identifier);

@interface DPChatGPTCard : DPTabIntegrationListPreview
@end
NSView *DPChatGPTConversationRow(NSDictionary *row, BOOL pinned, void (^open)(void), void (^pin)(void));
