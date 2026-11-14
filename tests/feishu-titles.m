#import <Foundation/Foundation.h>
#import "Patches/FeishuTabTitles/Title.h"

int main(void) {
    @autoreleasepool {
        NSURL *wiki = [NSURL URLWithString:@"https://tenant.feishu.cn/wiki/example"];
        NSURL *document = [NSURL URLWithString:@"https://docs.feishu.cn/docx/example"];
        NSURL *other = [NSURL URLWithString:@"https://example.com/"];
        NSString *raw = @"\u200D\u2061\u200B\u200C\u202C\uFEFF文档标题 - 飞书云文档";
        NSCAssert([DPFeishuDisplayTitle(raw, wiki) isEqual:@"文档标题 - 飞书云文档"], @"Wiki title");
        NSCAssert([DPFeishuDisplayTitle(raw, document) isEqual:@"文档标题 - 飞书云文档"], @"Document title");
        NSString *prefix = [@"" stringByPaddingToLength:64 withString:@"\u200B" startingAtIndex:0];
        NSCAssert([DPFeishuDisplayTitle([prefix stringByAppendingString:@"文档标题"], wiki) isEqual:@"文档标题"], @"Long prefix");
        NSCAssert(DPFeishuDisplayTitle(raw, other) == raw, @"Other sites retain their string");
        NSCAssert(DPFeishuDisplayTitle(raw, [NSURL URLWithString:@"https://feishu.cn.example.com/"]) == raw, @"Suffix boundary");
        NSCAssert(DPFeishuDisplayTitle(raw, [NSURL URLWithString:@"https://notfeishu.cn/"]) == raw, @"Unrelated host");
        NSCAssert(DPFeishuDisplayTitle(raw, nil) == raw, @"Missing URL");
        NSCAssert([raw hasPrefix:@"\u200D"], @"Input remains intact");
        NSCAssert([DPFeishuDisplayTitle(@"正常标题", wiki) isEqual:@"正常标题"], @"Plain title");
        NSCAssert([DPFeishuDisplayTitle(@"\u200B标题\u200D后缀", wiki) isEqual:@"标题\u200D后缀"], @"Interior characters");
        NSCAssert([DPFeishuDisplayTitle(@"\u200B\uFEFF", wiki) isEqual:@"\u200B\uFEFF"], @"Empty visible title");
        NSCAssert([DPFeishuDisplayTitle(@"", wiki) isEqual:@""], @"Empty title");
        NSCAssert(DPFeishuDisplayTitle(nil, wiki) == nil, @"Missing title");
        puts("Feishu native title tests passed");
    }
    return 0;
}
