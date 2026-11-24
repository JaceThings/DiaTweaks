#import "Canvas.h"
@implementation DPEaselCanvas (ImportCancellation)
- (void)cancelImageImport {
    self.importGeneration++;
    if(self.pendingAsset && !self.pendingAssetCommitted) [DPEaselStore.shared discardUnplacedAsset:self.pendingAsset document:self.document];
    self.pendingAsset=nil; self.pendingAssetCommitted=NO;
}
@end
