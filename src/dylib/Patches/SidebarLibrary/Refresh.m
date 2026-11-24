#import "Library.h"
void DPLibraryInvalidateFavicons(NSString *profile);
@implementation DPLibraryController (Refresh)
- (void)refreshLibrary:(id)sender {
    DPLibraryAnimateRefresh(self.refresh);
    NSString *context = DPLibraryContextForWindow(self.window);
    if (context) self.context = context;
    DPLibraryInvalidateFavicons(self.context);
    self.listingState = nil;
    if ([self.section isEqual:@"Archived Tabs"]) {
        NSUInteger generation = ++self.archiveGeneration; NSString *profile = self.context;
        __weak DPLibraryController *weak = self;
        DPLibraryLoadArchive(profile,^(NSArray *records) {
            if (weak.archiveGeneration != generation || ![weak.context isEqual:profile]) return;
            weak.archive = records; weak.listingState = nil; [weak reload];
        });
    }
    [self reload]; [self.collection.collectionViewLayout invalidateLayout];
}
@end
