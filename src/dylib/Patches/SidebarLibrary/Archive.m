#import "Library.h"
BOOL DPLibraryCanOpenArchivedURL(NSURL *url) {
    NSString *scheme = url.scheme.lowercaseString;
    if ([@[@"http",@"https"] containsObject:scheme]) return url.host.length > 0;
    if ([scheme isEqual:@"file"]) return url.path.isAbsolutePath;
    if ([@[@"dia",@"chrome",@"chrome-extension"] containsObject:scheme]) return url.host.length > 0;
    return [scheme isEqual:@"about"] && [@[@"blank",@"newtab"] containsObject:url.resourceSpecifier];
}
NSArray<DPLibraryFile *> *DPLibraryParseArchive(NSData *data, NSString *profile) {
    if (!data.length || data.length > 32*1024*1024 || !profile.length) return @[];
    id decoded = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    if (![decoded isKindOfClass:NSDictionary.class] || ![decoded[@"version"] isEqual:@2] ||
        ![decoded[@"containers"] isKindOfClass:NSArray.class]) return @[];
    NSMutableArray *records = [NSMutableArray new];
    for (id container in decoded[@"containers"]) {
        if (![container isKindOfClass:NSDictionary.class]) continue;
        id identity = container[@"id"], archivedProfile = [identity isKindOfClass:NSDictionary.class] ? identity[@"profile"] : nil;
        if (![archivedProfile isKindOfClass:NSDictionary.class] || ![archivedProfile[@"_0"] isEqual:profile] ||
            ![container[@"archivedTabs"] isKindOfClass:NSArray.class]) continue;
        for (id entry in container[@"archivedTabs"]) {
            if (![entry isKindOfClass:NSDictionary.class] || ![entry[@"id"] isKindOfClass:NSString.class] ||
                ![entry[@"url"] isKindOfClass:NSString.class] || ![entry[@"archiveDate"] isKindOfClass:NSNumber.class]) continue;
            NSURLComponents *url = [NSURLComponents componentsWithString:entry[@"url"]];
            if (!DPLibraryCanOpenArchivedURL(url.URL) || !isfinite([entry[@"archiveDate"] doubleValue])) continue;
            DPLibraryFile *file = [DPLibraryFile new]; file.archived = YES; file.profile=profile; file.state = 2;
            file.identifier = entry[@"id"]; file.source = url.URL.absoluteString; file.path = @"";
            file.title = [entry[@"title"] isKindOfClass:NSString.class] && [entry[@"title"] length] ? entry[@"title"] : (url.host ?: url.path.lastPathComponent ?: @"Untitled tab");
            file.spaceID = [entry[@"spaceID"] isKindOfClass:NSString.class] ? entry[@"spaceID"] : nil;
            file.date = [NSDate dateWithTimeIntervalSinceReferenceDate:[entry[@"archiveDate"] doubleValue]];
            [records addObject:file];
        }
    }
    return [records sortedArrayUsingComparator:^NSComparisonResult(DPLibraryFile *a,DPLibraryFile *b) { return [b.date compare:a.date]; }];
}
void DPLibraryLoadArchive(NSString *profile, void (^completion)(NSArray<DPLibraryFile *> *)) {
    // Read Dia's atomic archive snapshot; never write or delete its entries.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
        NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;
        NSString *path = [support stringByAppendingPathComponent:@"Dia/StorableAutoArchive.json"];
        NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
        NSArray *records = DPLibraryParseArchive(data,profile);
        dispatch_async(dispatch_get_main_queue(), ^{ completion(records); });
    });
}
