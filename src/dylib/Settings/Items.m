#import "Settings.h"

DPItem DPPatchItem(DPPatch *patch) {
    return (DPItem){patch, patch->key, patch->title, patch->detail, patch->symbol, patch->tint, nil};
}

NSArray<NSValue *> *DPOptions(DPPatch *patch) {
    NSMutableArray<NSValue *> *options = [NSMutableArray new];
    for (NSUInteger i = 0; i < DPPatchCount; i++)
        if (DPRequired(DPPatches[i]) == patch) [options addObject:[NSValue valueWithPointer:DPPatches[i]]];
    return options;
}

NSString *DPWhyDisabled(DPPatch *patch) {
    if (patch->unavailable) return @"Unavailable on this Dia version.";
    DPPatch *disabler = DPPatchNamed(patch->disabledBy);
    return disabler && disabler->on ? [NSString stringWithFormat:@"Off while %@ is on.", disabler->title] : nil;
}

// Wiki pages are named after the title, with spaces as hyphens.
NSURL *DPWikiURL(DPItem item) {
    NSString *page = [item.title stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    return [NSURL URLWithString:[@"https://github.com/JaceThings/DiaTweaks/wiki/" stringByAppendingString:page]];
}
