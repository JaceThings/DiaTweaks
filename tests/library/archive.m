#import "Patches/SidebarLibrary/Library.h"
int main(void) { @autoreleasepool {
    NSDate *now = NSDate.date;
    NSDictionary *tab = @{@"id":@"fixture-tab",@"title":@"Example Page",@"url":@"https://example.com/page",@"archiveDate":@(now.timeIntervalSinceReferenceDate),@"spaceID":@"fixture-space"};
    NSDictionary *other = @{@"id":@{@"profile":@{@"_0":@"other-profile"}},@"archivedTabs":@[tab]};
    NSDictionary *current = @{@"id":@{@"profile":@{@"_0":@"fixture-profile"}},@"archivedTabs":@[tab]};
    NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"version":@2,@"containers":@[other,current]} options:0 error:nil];
    NSArray *records = DPLibraryParseArchive(data,@"fixture-profile");
    NSCAssert(records.count == 1,@"archive isolated to active profile");
    DPLibraryFile *file = records.firstObject;
    NSCAssert(file.archived && [file.title isEqual:@"Example Page"] && [file.spaceID isEqual:@"fixture-space"],@"archive retains native metadata");
    NSCAssert(fabs([file.date timeIntervalSinceDate:now]) < 0.01,@"native Apple reference timestamp");
    NSCAssert(DPLibraryParseArchive(data,@"missing-profile").count == 0,@"no cross-profile fallback");
    NSCAssert(DPLibraryParseArchive([@"broken" dataUsingEncoding:NSUTF8StringEncoding],@"fixture-profile").count == 0,@"partial write rejected");
    NSData *future = [NSJSONSerialization dataWithJSONObject:@{@"version":@999,@"containers":@[current]} options:0 error:nil];
    NSCAssert(DPLibraryParseArchive(future,@"fixture-profile").count == 0,@"unknown schema fails closed");
    NSArray *rows = DPLibraryDateSections(records,now);
    NSCAssert(rows.count == 2 && [rows.firstObject isEqual:@"Today"],@"date section and entry");
    NSCAssert(DPLibraryCanOpenArchivedURL([NSURL URLWithString:@"file:///tmp/Example.pdf"]),@"local archived documents remain browser tabs");
    NSCAssert(DPLibraryCanOpenArchivedURL([NSURL URLWithString:@"dia://example/report"]),@"Dia generated-page URLs supported");
    NSCAssert(!DPLibraryCanOpenArchivedURL([NSURL URLWithString:@"javascript:alert(1)"]),@"no script URLs");
    NSCAssert(!DPLibraryCanOpenArchivedURL([NSURL URLWithString:@"magnet:example"]),@"no external protocol launch");
    NSLog(@"PASS: native archive schema, profile isolation, timestamps, malformed input and date groups");
} }
