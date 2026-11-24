#import "Library.h"
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation DPLibraryFile
- (NSString *)key { return self.profile.length ? [NSString stringWithFormat:@"%@|%@",self.profile,self.identifier ?: @""] : self.identifier; }
@end
static UTType *DPLibraryFileType(NSString *extension) {
    if (![extension isKindOfClass:NSString.class] || !extension.length || extension.length > 128) return nil;
    // Native file metadata may contain an invalid tag; classification must not
    // turn a missing or unusual download into an application exception.
    @try { return [NSClassFromString(@"UTType") typeWithFilenameExtension:extension]; }
    @catch (NSException *exception) { return nil; }
}
BOOL DPLibraryIsMovieURL(NSURL *url) {
    return [DPLibraryFileType(url.pathExtension) conformsToType:[NSClassFromString(@"UTType") typeWithIdentifier:@"public.movie"]];
}
BOOL DPLibraryIsMedia(DPLibraryFile *file) {
    UTType *type = DPLibraryFileType(file.path.pathExtension);
    return [type conformsToType:[NSClassFromString(@"UTType") typeWithIdentifier:@"public.image"]] || [type conformsToType:[NSClassFromString(@"UTType") typeWithIdentifier:@"public.movie"]];
}
NSArray<DPLibraryFile *> *DPLibraryFiltered(NSArray<DPLibraryFile *> *files, NSString *query, NSInteger filter, BOOL media) {
    NSString *text = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSMutableArray *result = [NSMutableArray new];
    for (DPLibraryFile *file in files) {
        if (!file.path.isAbsolutePath || file.state == 3) continue;
        if (media && (!DPLibraryIsMedia(file) || file.state != 2)) continue;
        // Download history outlives the file. Keep that record in Downloads,
        // but do not turn a missing image into a generic document in Media.
        if (media) {
            BOOL directory = NO;
            if (![NSFileManager.defaultManager fileExistsAtPath:file.path isDirectory:&directory] || directory) continue;
        }
        if (filter == 1 && file.state != 2) continue;
        if (filter == 2 && file.state != 1) continue;
        if (text.length && [file.path.lastPathComponent rangeOfString:text options:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch].location == NSNotFound) continue;
        [result addObject:file];
    }
    return [result sortedArrayUsingComparator:^NSComparisonResult(DPLibraryFile *a, DPLibraryFile *b) {
        NSComparisonResult order = [b.date compare:a.date];
        return order == NSOrderedSame ? [a.identifier compare:b.identifier] : order;
    }];
}
