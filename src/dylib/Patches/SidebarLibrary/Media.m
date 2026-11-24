#import "Library.h"
@implementation DPLibraryMediaItem
- (void)loadView {
    DPLibraryMediaView *view = [[DPLibraryMediaView alloc] initWithFrame:NSMakeRect(0,0,172,150)]; self.view = view;
    self.imageView = view.imageView;
}
- (void)prepareForReuse {
    [super prepareForReuse]; self.representedObject = nil;
    DPLibraryMediaView *view = (id)self.view; [view resetHover]; view.chosen = NO;
    self.imageView.image = nil; [view refreshImage];
}
- (void)setSelected:(BOOL)selected {
    [super setSelected:selected]; DPLibraryMediaView *view = (id)self.view; view.chosen = selected; [view refreshImage];
}
@end
@implementation DPLibraryController (Media)
- (void)collectionView:(NSCollectionView *)collection draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)point forItemsAtIndexPaths:(NSSet<NSIndexPath *> *)paths {
    self.dragging = YES;
    [session enumerateDraggingItemsWithOptions:0 forView:collection classes:@[NSURL.class] searchOptions:@{} usingBlock:^(NSDraggingItem *drag,NSInteger index,BOOL *stop) {
        NSURL *url=[drag.item isKindOfClass:NSURL.class] ? drag.item : nil;
        for (NSIndexPath *path in paths) {
            if (path.item<0 || (NSUInteger)path.item>=self.mediaFiles.count || ![self.mediaFiles[path.item].path isEqual:url.path]) continue;
            DPLibraryMediaView *view=(id)[collection itemAtIndexPath:path].view;
            NSImage *image=[view framedImage];
            if (image) [drag setDraggingFrame:[collection convertRect:view.framedRect fromView:view] contents:image];
        }
    }];
}
- (void)collectionView:(NSCollectionView *)collection draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)point dragOperation:(NSDragOperation)operation {
    self.dragging = NO;
    for (NSCollectionViewItem *item in collection.visibleItems) [(DPLibraryMediaView *)item.view resetHover];
    self.reloadAfterDrag = NO; self.listingState = nil; [self reload];
}
- (NSInteger)collectionView:(NSCollectionView *)collection numberOfItemsInSection:(NSInteger)section { return self.mediaFiles.count; }
- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collection itemForRepresentedObjectAtIndexPath:(NSIndexPath *)path {
    if (path.item < 0 || path.item >= (NSInteger)self.mediaFiles.count) {
        DPLibraryMediaItem *empty = [DPLibraryMediaItem new]; empty.view.hidden = YES; return empty;
    }
    DPLibraryMediaItem *item = [collection makeItemWithIdentifier:@"media" forIndexPath:path]; item.view.hidden = NO;
    DPLibraryFile *file = self.mediaFiles[path.item]; item.representedObject = file.path;
    item.view.toolTip = [NSFileManager.defaultManager fileExistsAtPath:file.path] ? file.path.lastPathComponent : [file.path.lastPathComponent stringByAppendingString:@" — File moved or unavailable"]; item.imageView.accessibilityLabel = file.path.lastPathComponent;
    item.imageView.image = [NSWorkspace.sharedWorkspace iconForFile:file.path]; [(DPLibraryMediaView *)item.view refreshImage];
    __weak DPLibraryMediaItem *weak = item;
    DPLibraryThumbnail([NSURL fileURLWithPath:file.path], ^(NSImage *image) {
        if (image && [weak.representedObject isEqual:file.path]) { weak.imageView.image = image; [(DPLibraryMediaView *)weak.view refreshImage]; }
    });
    return item;
}
- (NSSize)collectionView:(NSCollectionView *)collection layout:(NSCollectionViewLayout *)layout sizeForItemAtIndexPath:(NSIndexPath *)path {
    CGFloat width = NSWidth(self.mediaScroll.contentView.bounds);
    return NSMakeSize(MAX(60,floor(width < 280 ? width-16 : (width-28)/2)),150);
}
- (NSImage *)collectionView:(NSCollectionView *)collection draggingImageForItemsAtIndexPaths:(NSSet<NSIndexPath *> *)paths withEvent:(NSEvent *)event offset:(NSPointPointer)offset {
    NSIndexPath *path=paths.anyObject;
    DPLibraryMediaView *view=(id)[collection itemAtIndexPath:path].view;
    NSImage *image=[view framedImage];
    if (offset) *offset=NSZeroPoint;
    return image ?: [NSImage new];
}
- (id<NSPasteboardWriting>)collectionView:(NSCollectionView *)collection pasteboardWriterForItemAtIndexPath:(NSIndexPath *)path {
    if (path.item < 0 || path.item >= (NSInteger)self.mediaFiles.count) return nil;
    DPLibraryFile *file = self.mediaFiles[path.item];
    return [NSFileManager.defaultManager fileExistsAtPath:file.path] ? [NSURL fileURLWithPath:file.path] : nil;
}
@end
