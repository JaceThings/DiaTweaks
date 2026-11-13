#import "Title.h"

NSString *DPFeishuDisplayTitle(NSString *title, NSURL *url) {
    NSString *host = url.host.lowercaseString;
    if (![host isEqualToString:@"feishu.cn"] && ![host hasSuffix:@".feishu.cn"]) return title;

    NSUInteger prefixLength = 0;
    while (prefixLength < title.length) {
        unichar character = [title characterAtIndex:prefixLength];
        BOOL invisible = (character >= 0x200B && character <= 0x200F) ||
                         (character >= 0x202A && character <= 0x202E) ||
                         (character >= 0x2060 && character <= 0x206F) ||
                         character == 0xFEFF;
        if (!invisible) break;
        prefixLength++;
    }
    if (!prefixLength || prefixLength == title.length) return title;
    return [title substringFromIndex:prefixLength];
}
