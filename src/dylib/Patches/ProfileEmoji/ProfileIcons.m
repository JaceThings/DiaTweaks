#import "ProfileIcons.h"

static NSString *const DPEmojisKey = @"profileEmojis", *const DPSymbolsKey = @"profileSymbols";
NSUserDefaults *DPEmojiDefaults;

static NSString *DPProfileValue(NSString *key, NSString *spaceID) {
    id value = spaceID ? [DPEmojiDefaults dictionaryForKey:key][spaceID] : nil;
    return [value isKindOfClass:NSString.class] && [value length] ? value : nil;
}

NSString *DPProfileEmojiValue(NSString *spaceID) { return DPProfileValue(DPEmojisKey, spaceID); }
NSString *DPProfileSymbolName(NSString *spaceID) { return DPProfileValue(DPSymbolsKey, spaceID); }

NSString *DPProfilePreferredSymbolName(NSString *name) {
    if (!name.length) return nil;
    NSString *filled = [name hasSuffix:@".fill"] ? name : [name stringByAppendingString:@".fill"];
    if ([NSImage imageWithSystemSymbolName:filled accessibilityDescription:nil]) return filled;
    return [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil] ? name : nil;
}

NSImage *DPProfileSymbolImage(NSString *name, CGFloat size) {
    name = DPProfilePreferredSymbolName(name);
    if (!name) return nil;
    NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:name];
    NSImageSymbolConfiguration *config = [[NSImageSymbolConfiguration configurationWithPointSize:size weight:NSFontWeightMedium]
        configurationByApplyingConfiguration:NSImageSymbolConfiguration.configurationPreferringMonochrome];
    image = [image imageWithSymbolConfiguration:config];
    image.template = YES;
    return image;
}

BOOL DPProfileHasIcon(NSString *spaceID) {
    return DPProfileEmoji.on && (DPProfilePreferredSymbolName(DPProfileSymbolName(spaceID)) || DPProfileEmojiValue(spaceID));
}

void DPStoreProfileIcon(NSString *spaceID, NSString *emoji, NSString *symbol) {
    if (!spaceID) return;
    for (NSString *key in @[ DPEmojisKey, DPSymbolsKey ]) {
        NSMutableDictionary *values = [[DPEmojiDefaults dictionaryForKey:key] mutableCopy] ?: [NSMutableDictionary dictionary];
        NSString *value = [key isEqual:DPEmojisKey] ? emoji : symbol;
        values[spaceID] = value.length ? value : nil;
        [DPEmojiDefaults setObject:values forKey:key];
    }
    DPRefreshProfileIcons();
}
