#import "TabIntegrations/TabIntegrations.h"

extern DPPatch DPChatGPTPreview;
extern DPTabIntegration DPChatGPTIntegration;
BOOL DPChatGPTURL(NSString *value);
NSString *DPChatGPTConversationURL(NSString *identifier);

@interface DPChatGPTCard : DPTabIntegrationPreview
@property(nonatomic, strong) DPTabIntegrationPage *page;
@property(nonatomic, strong) NSTimer *refresh;
@property(nonatomic, copy) NSDictionary *displayed;
@property(nonatomic) NSTimeInterval startedAt;
- (void)update;
@end
NSView *DPChatGPTConversationRow(NSDictionary *row, BOOL pinned, void (^open)(void), void (^pin)(void));
