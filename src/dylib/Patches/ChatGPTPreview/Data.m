#import "ChatGPTPreview.h"

BOOL DPChatGPTURL(NSString *value) {
    return DPTabIntegrationAllowsURL(value, DPIntegrationOrigins("https://chatgpt.com"));
}

NSString *DPChatGPTConversationURL(NSString *identifier) {
    if (![identifier isKindOfClass:NSString.class] || !identifier.length || identifier.length > 128) return nil;
    NSCharacterSet *valid = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"];
    if ([identifier rangeOfCharacterFromSet:valid.invertedSet].location != NSNotFound) return nil;
    return [@"https://chatgpt.com/c/" stringByAppendingString:identifier];
}
