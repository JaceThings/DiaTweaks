#import "Canvas.h"
@implementation DPEaselEditorSurface (ImageImport)
- (void)completeImageImport:(NSString *)asset size:(NSSize)size error:(NSError *)error document:(DPEaselDocument *)document generation:(NSUInteger)generation {
    if(!self.superview || self.canvas.importGeneration!=generation || self.canvas.document!=document || document.deleted) {
        if(asset) [DPEaselStore.shared discardUnplacedAsset:asset document:document]; return;
    }
    if(error) { [self.canvas reportImportError:error]; return; }
    [self.canvas selectTool:@"image"]; self.canvas.pendingAsset=asset; self.canvas.pendingSize=size;
    self.canvas.pendingPoint=NSMakePoint(NSMidX(self.canvas.visibleRect),NSMidY(self.canvas.visibleRect)); self.canvas.needsDisplay=YES;
}
@end
