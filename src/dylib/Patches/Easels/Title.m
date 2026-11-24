#import "Easels.h"
NSString *DPEaselDisplayTitle(NSString *title) {
    if(title.length<=80) return title;
    return [[title substringWithRange:[title rangeOfComposedCharacterSequencesForRange:NSMakeRange(0,80)]] stringByAppendingString:@"…"];
}

BOOL DPEaselUUID(NSString *value) {
    return [value isKindOfClass:NSString.class] && [[NSUUID alloc] initWithUUIDString:value] &&
        [value isEqual:[[NSUUID alloc] initWithUUIDString:value].UUIDString];
}
NSString *DPEaselTitle(NSArray<NSDictionary *> *objects) {
    NSArray *ordered = [objects sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b) {
        return [a[@"order"] compare:b[@"order"]];
    }];
    for (NSDictionary *object in ordered) {
        if (![object[@"type"] isEqual:@"text"] || ![object[@"isTitle"] boolValue]) continue;
        for (NSString *line in [object[@"text"] componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]) {
            NSArray *words = [line componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
            NSString *name = [[words filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSString *s,id bindings) { return s.length > 0; }]] componentsJoinedByString:@" "];
            if (name.length) return name;
        }
    }
    return @"Untitled";
}
NSDictionary *DPEaselText(NSString *text,NSRect frame,NSUInteger order,BOOL placeholder) {
    return @{@"id":NSUUID.UUID.UUIDString,@"type":@"text",@"order":@(order),@"z":@(order),
        @"rect":@[@(frame.origin.x),@(frame.origin.y),@(frame.size.width),@(frame.size.height)],
        @"text":text ?: @"",@"font":@"sans",@"size":@(placeholder ? 56 : 24),@"bold":@(placeholder),@"placeholder":@(placeholder),@"isTitle":@(placeholder)};
}
NSString *DPEaselEscapeHTML(NSString *text) {
    NSMutableString *result = [text mutableCopy] ?: NSMutableString.new;
    for (NSArray *pair in @[@[@"&",@"&amp;"],@[@"<",@"&lt;"],@[@">",@"&gt;"],@[@"\"",@"&quot;"],@[@"'",@"&#39;"]])
        [result replaceOccurrencesOfString:pair[0] withString:pair[1] options:0 range:NSMakeRange(0,result.length)];
    return result;
}

NSDictionary *DPEaselPrepareTitleSnapshot(NSDictionary *snapshot) {
    if([snapshot[@"titleModel"] isEqual:@2]) return snapshot;
    NSMutableDictionary *prepared=[snapshot mutableCopy]; NSMutableArray *objects=[snapshot[@"objects"] mutableCopy];
    NSArray *ordered=[objects sortedArrayUsingComparator:^NSComparisonResult(NSDictionary *a,NSDictionary *b){ return [a[@"order"] compare:b[@"order"]]; }];
    for(NSDictionary *object in ordered) {
        BOOL oldHeading=[object[@"type"] isEqual:@"text"] && ([object[@"isTitle"] boolValue] || [object[@"placeholder"] boolValue] ||
            ([object[@"order"] unsignedIntegerValue]==0 && [object[@"bold"] boolValue] && [object[@"size"] doubleValue]>=32));
        if(!oldHeading) continue;
        NSMutableDictionary *heading=[object mutableCopy]; heading[@"isTitle"]=@YES;
        if([heading[@"placeholder"] boolValue] && [heading[@"text"] isEqual:@"Untitled Easel"]) heading[@"text"]=@"Untitled";
        objects[[objects indexOfObjectIdenticalTo:object]]=[heading copy]; break;
    }
    prepared[@"titleModel"]=@2; prepared[@"objects"]=[objects copy]; return [prepared copy];
}
