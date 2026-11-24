#import "Patches/SidebarLibrary/Library.h"
#import <objc/runtime.h>
@interface FixtureProgressTable : NSTableView @end
@implementation FixtureProgressTable
- (NSRect)visibleRect { return NSIntersectionRect(self.bounds,NSMakeRect(0,0,406,560)); }
@end
DPPatch DPSidebarLibraryDust={.on=YES};
@interface DPLibraryController (FixtureInputActions)
- (void)filterChanged:(id)sender;
- (BOOL)validateMenuItem:(NSMenuItem *)item;
@end
BOOL DPIsKind(id object,const char *name) { return NO; }
id DPSwiftValue(id object,NSString *key) { return nil; }
BOOL DPLibraryCanOpenArchivedURL(NSURL *url) { return [url.scheme isEqual:@"https"]; }
id DPLibraryContextForWindow(NSWindow *window) { return @"fixture"; }
NSString *DPLibraryActiveSpace(NSWindow *window) { return @"fixture-space"; }
#include <string.h>
DPPatch DPSidebarLibrary;
NSNotificationName const DPLibraryDownloadsChanged = @"LibraryFixtureChanged";
static NSArray *fixtures;
NSView *DPSubview(NSView *root,const char *name) { return nil; }
NSView *DPFindView(NSView *root,BOOL (^match)(NSView *)) { return nil; }
void DPLibraryCoverTabs(DPLibraryController *controller) {}
void DPLibraryUpdateInteractiveLayout(DPLibraryController *controller) {}
void DPLibraryUpdateHosts(DPLibraryController *controller) { [controller layout]; }
void DPLibraryClosePreview(DPLibraryController *controller) {}
void DPLibraryTogglePreview(DPLibraryController *controller,NSResponder *responder) {}
void DPLibraryHideFiles(id context,NSArray *files) {}
BOOL DPLibraryOpenArchivedURL(NSWindow *window,NSURL *url) { return YES; }
NSArray *DPLibraryFiles(id context) { return fixtures; }
NSArray *DPLibraryAllFiles(id context) { return fixtures; }
NSArray *DPLibrarySharedMediaFiles(BOOL hidden) { return hidden ? @[] : fixtures; }
NSUInteger DPLibraryHiddenMediaCount(void) { return 0; }
void DPLibraryRestoreHiddenMedia(void) {}
void DPLibraryUpdateChrome(DPLibraryController *owner) {}
void DPLibraryInvalidateFavicons(NSString *profile) {}
void DPLibraryLoadArchive(NSString *profile,void (^completion)(NSArray *)) { completion(@[]); }
void DPLibraryThumbnail(NSURL *url,void (^completion)(NSImage *)) { completion(nil); }
void DPLibraryFavicon(NSString *profile,NSString *source,void (^completion)(NSImage *)) { completion(nil); }
BOOL DPLibraryMount(DPLibraryController *controller) {
    controller.sidebarHost = controller.window.contentView; controller.expanded = YES; controller.expandedWidth = 510;
    [controller.sidebarHost addSubview:controller.view]; [controller.sidebarHost layoutSubtreeIfNeeded]; return YES;
}
void DPLibraryUnmount(DPLibraryController *controller) { [controller.view removeFromSuperview]; controller.expanded = NO; controller.sidebarHost = nil; }
void DPLibraryAnimate(DPLibraryController *controller,BOOL opening) { if (!opening) DPLibraryUnmount(controller); }
@interface FixtureHost : NSView @end
@implementation FixtureHost
- (BOOL)isFlipped { return YES; }
@end
static NSButton *section(DPLibraryController *controller,NSInteger tag) {
    for (NSButton *button in controller.rail.subviews) if ([button.identifier isEqual:@"category"] && button.tag == tag) return button;
    abort();
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSString *path = @"/tmp/sidebar-library-lifecycle-fixture.png";
    [@"fixture" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    NSMutableArray *records = [NSMutableArray new];
    for (NSUInteger i=0;i<40;i++) {
        DPLibraryFile *file = [DPLibraryFile new]; file.identifier = [NSString stringWithFormat:@"fixture-%lu",i];
        file.path = i < 18 ? path : @"/tmp/Library Document.txt"; file.title = @"Fixture";
        file.date = [NSDate dateWithTimeIntervalSinceNow:-(double)i*3600]; file.state = 2; [records addObject:file];
    }
    fixtures = records;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,510,700) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.contentView = [[FixtureHost alloc] initWithFrame:NSMakeRect(0,0,510,700)]; // Never order the fixture window onscreen.
    DPLibraryController *controller = [[DPLibraryController alloc] initWithWindow:window context:@"fixture"];
    NSUserDefaults *settings = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    id oldSection = [settings objectForKey:@"sidebarLibrarySection"];
    @try { for (NSUInteger pass=0;pass<60;pass++) {
        [controller show]; [controller chooseSection:section(controller,0)];
        NSCAssert(controller.mediaFiles.count == 18,@"media publishes its own immutable snapshot");
        [controller.collection layoutSubtreeIfNeeded];
        [controller chooseSection:section(controller,1)];
        controller.search.stringValue = @"no results"; [controller reload];
        NSCAssert(controller.files.count == 0 && controller.mediaFiles.count == 18,@"empty Downloads search cannot invalidate hidden Media indexes");
        [controller.collection layoutSubtreeIfNeeded];
        [controller chooseSection:section(controller,2)]; [controller.table layoutSubtreeIfNeeded];
        [controller close]; [controller show]; [controller close];
    }
    [controller chooseSection:section(controller,0)];
    [NSFileManager.defaultManager removeItemAtPath:path error:nil]; [controller reload];
    NSCAssert(controller.mediaFiles.count == 0,@"missing files do not become generic document tiles in Media");
    [controller chooseSection:section(controller,1)];
    NSCAssert(controller.files.count == 40,@"unavailable files retain their Downloads history without being hidden or deleted");
    [controller chooseSection:section(controller,0)];
    [@"fixture" writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]; [controller reload];
    NSCAssert(controller.mediaFiles.count == 18,@"identical download metadata recovers when files return");
    [controller.refresh layoutSubtreeIfNeeded];
    CALayer *glyph = nil; for (CALayer *layer in controller.refresh.layer.sublayers) if ([layer.name isEqual:@"LibraryRefreshGlyph"]) glyph = layer;
    NSCAssert(glyph && glyph.contents,@"refresh has a real isolated glyph layer");
    DPLibraryMediaView *framed=[[DPLibraryMediaView alloc] initWithFrame:NSMakeRect(0,0,170,150)];
    framed.imageView.image=[NSImage imageWithSystemSymbolName:@"photo" accessibilityDescription:nil]; [framed refreshImage];
    NSCAssert(framed.framedImage && NSWidth(framed.framedRect)>NSWidth(framed.imageView.frame),@"drag snapshot includes the white mat around the image");
    NSCAssert(framed.imageView.superview.layer.cornerRadius==0,@"media frames have sharp corners");
    NSRect initialBox=controller.sectionHighlight.frame;
    [controller chooseSection:section(controller,1)];
    NSCAssert(!NSEqualRects(initialBox,controller.sectionHighlight.frame),@"one selection box moves between sections");
    DPLibraryButton *utility=(id)controller.options; utility.hovered=YES; [utility viewDidMoveToWindow];
    NSCAssert(!utility.hovered,@"utility hover resets when its window attachment changes");
    CGPoint position = glyph.position; NSRect buttonFrame = controller.refresh.frame;
    DPLibraryAnimateRefresh(controller.refresh);
    NSCAssert(CGPointEqualToPoint(glyph.anchorPoint,CGPointMake(.5,.5)) && CGPointEqualToPoint(glyph.position,position) && NSEqualRects(controller.refresh.frame,buttonFrame),@"refresh rotates on its own center without moving the button or glyph");
    CAKeyframeAnimation *tilt = (id)[glyph animationForKey:@"libraryRefresh"];
    NSCAssert([tilt isKindOfClass:CAKeyframeAnimation.class] && [tilt.values.lastObject doubleValue] == 0 && fabs([tilt.values[1] doubleValue])<.3,@"refresh tilts gently and returns upright");
    NSCAssert(![controller.refresh.layer animationForKey:@"libraryRefresh"],@"the button container never rotates");
    controller.dragging = YES; [controller reload];
    NSCAssert(controller.reloadAfterDrag && controller.mediaFiles.count == 18,@"updates during drag retain the active snapshot");
    controller.dragging = NO; [controller refreshLibrary:nil];
    NSCAssert(controller.mediaFiles.count == 18,@"refresh rebuilds Media after drag");
    [controller chooseSection:section(controller,1)];
    [controller.filter selectItemAtIndex:1]; [controller filterChanged:nil];
    NSCAssert(controller.filterIndex == 1 && [[controller.filter itemTitleAtIndex:1] isEqual:@"Complete"],@"Filter label preserves real menu choices and selection");
    [controller chooseSection:section(controller,2)];
    [controller.filter.menu update];
    for (NSMenuItem *item in controller.filter.itemArray) NSCAssert([controller validateMenuItem:item] && item.enabled,@"archive filtering is enabled without a selected file");
    NSMutableArray *archive = [NSMutableArray new];
    for (NSNumber *days in @[@0,@(-1),@(-40)]) {
        DPLibraryFile *file = [DPLibraryFile new]; file.identifier = days.stringValue; file.archived = YES;
        file.title = @"Archive fixture"; file.source = @"https://example.com/page";
        file.date = [NSCalendar.currentCalendar dateByAddingUnit:NSCalendarUnitDay value:days.integerValue toDate:NSDate.date options:0];
        [archive addObject:file];
    }
    controller.archive = archive;
    controller.filterIndex = 1; [controller reload]; NSCAssert(controller.files.count == 1,@"Today excludes older archive records");
    controller.filterIndex = 2; [controller reload]; NSCAssert(controller.files.count == 2,@"Past week applies archive cutoff");
    controller.filterIndex = 0; [controller reload]; NSCAssert(controller.files.count == 3,@"All dates restores archive records");
    DPLibraryMediaView *tile = [[DPLibraryMediaView alloc] initWithFrame:NSMakeRect(0,0,172,150)];
    tile.imageView.image = [[NSImage alloc] initWithSize:NSMakeSize(200,100)]; [tile refreshImage];
    NSView *mat = tile.subviews.firstObject; NSRect base = mat.frame, imageFrame = tile.imageView.frame;
    NSEvent *hoverEvent = [NSEvent otherEventWithType:NSEventTypeApplicationDefined location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil subtype:0 data1:0 data2:0];
    [tile mouseEntered:hoverEvent]; [tile refreshImage];
    NSCAssert(NSEqualRects(base,mat.frame) && NSEqualRects(imageFrame,tile.imageView.frame),@"hover cannot mutate layout geometry");
    NSCAssert(fabs(mat.layer.transform.m11-1.025)<.001,@"whole image frame scales together");
    CATransform3D transform = mat.layer.transform;
    CGFloat centerX = (transform.m11-1)*NSWidth(mat.layer.bounds)*(.5-mat.layer.anchorPoint.x)+transform.m41;
    CGFloat centerY = (transform.m22-1)*NSHeight(mat.layer.bounds)*(.5-mat.layer.anchorPoint.y)+transform.m42;
    NSCAssert(fabs(centerX)<.001 && fabs(centerY)<.001,@"whole white image frame grows about its fixed center");
    CABasicAnimation *hover = (id)[mat.layer animationForKey:@"mediaHover"];
    NSCAssert(!hover || [hover.keyPath isEqual:@"transform"],@"scale and centering translation animate together without a position jump");
    [tile mouseExited:hoverEvent]; NSCAssert(fabs(mat.layer.transform.m11-1)<.001,@"hover returns to resting scale");
    } @finally {
        if (oldSection) [settings setObject:oldSection forKey:@"sidebarLibrarySection"]; else [settings removeObjectForKey:@"sidebarLibrarySection"];
    }
    [controller show]; [controller chooseSection:section(controller,1)]; [controller.table layoutSubtreeIfNeeded];
    controller.hasBackAnchor=YES;
    controller.backAnchor=[window.contentView convertRect:NSMakeRect(6,662,30,30) toView:nil];
    controller.interacting=YES; controller.expansion=.2; controller.layoutSignature=nil; [controller layout];
    NSView *back=nil; for(NSView *child in controller.rail.subviews) if([child.identifier isEqual:@"back"]) back=child;
    NSCAssert(back && fabs(NSMinX(back.frame)-6)<.001 && NSPointInRect(NSMakePoint(NSMidX(back.frame),NSMidY(back.frame)),controller.rail.bounds),@"first animated layout anchors Back inside the rail, independent of the offscreen Library origin");
    controller.expansion=1; [controller layout];
    NSCAssert(fabs(NSMinX(back.frame)-6)<.001 && NSPointInRect(NSMakePoint(NSMidX(back.frame),NSMidY(back.frame)),controller.rail.bounds),@"Back remains in the rail after settling without a click or cache invalidation");
    controller.interacting=NO; controller.hasBackAnchor=NO; controller.layoutSignature=nil; [controller layout];
    // The fixture is deliberately never ordered onscreen. Model a viewport so
    // visible-row updates can be tested without stealing the user's focus.
    object_setClass(controller.table,FixtureProgressTable.class);
    DPLibraryFile *active=records[0]; active.state=1; active.total=10000000; active.completed=1000000; active.remaining=600;
    [controller reload]; [controller.table layoutSubtreeIfNeeded];
    NSInteger activeRow=[controller.rows indexOfObject:active],completeRow=[controller.rows indexOfObject:records[1]];
    [controller.scroll layoutSubtreeIfNeeded]; [controller.table scrollRowToVisible:activeRow]; [controller.table layoutSubtreeIfNeeded];
    NSTableCellView *completed=[controller.table viewAtColumn:0 row:completeRow makeIfNecessary:YES];
    NSImage *thumbnail=[NSImage imageWithSystemSymbolName:@"photo" accessibilityDescription:nil]; completed.imageView.image=thumbnail;
    NSTableCellView *progressCell=[controller.table viewAtColumn:0 row:activeRow makeIfNecessary:YES];
    NSView *ring=nil; for(NSView *view in progressCell.subviews) if([NSStringFromClass(view.class) isEqual:@"DPLibraryDownloadProgress"]) ring=view;
    NSCAssert(ring && !ring.hidden && progressCell.imageView.hidden,@"in-progress file shows an accessible circular indicator instead of a placeholder image");
    for(NSUInteger i=0;i<80;i++) {
        active.completed+=50000; active.remaining=600-i;
        [controller reload];
        NSCAssert([controller.table viewAtColumn:0 row:completeRow makeIfNecessary:NO]==completed && completed.imageView.image==thumbnail,@"progress ticks retain completed cell and decoded thumbnail identity");
    }
    NSCAssert(fabs([[ring valueForKey:@"progress"] doubleValue]-.5)<.0001,@"circular progress tracks received bytes");
    NSCAssert([DPLibraryFileDetail(active) containsString:@"9 min remaining"],@"long download estimates use minutes rather than hundreds of seconds");
    active.paused=YES; [controller reload]; NSCAssert([[ring valueForKey:@"paused"] boolValue],@"paused ring tracks state without reloading rows");
    active.state=2; [controller reload]; NSCAssert(ring.hidden && !progressCell.imageView.hidden,@"completion replaces the ring with the file thumbnail");
    DPLibraryFile *missing=records[1]; NSString *savedPath=missing.path;
    missing.path=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    [controller reload];
    NSCAssert(missing.missing && [DPLibraryFileDetail(missing) isEqual:@"File moved or deleted"],@"external deletion changes the listing state and status");
    [controller updateFileCell:completed file:missing loadImage:NO];
    NSCAssert([[completed.textField.attributedStringValue attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:nil] integerValue]==NSUnderlineStyleSingle,@"missing download title is crossed out");
    missing.path=savedPath; [controller reload];
    [controller updateFileCell:completed file:missing loadImage:NO];
    NSCAssert(!missing.missing && [[completed.textField.attributedStringValue attribute:NSStrikethroughStyleAttributeName atIndex:0 effectiveRange:nil] integerValue]==0,@"restoring a file removes the strikethrough");
    NSButton *tipButton=[[NSClassFromString(@"DPLibraryArchiveActionButton") alloc] initWithFrame:NSMakeRect(0,0,30,30)];
    NSView *tip=NSView.new; [controller.view addSubview:tip]; [tipButton setValue:tip forKey:@"quickTip"];
    [tipButton setValue:@YES forKey:@"hovered"]; [tipButton setValue:@NO forKey:@"hovered"];
    NSCAssert(!tip.superview && ![tipButton valueForKey:@"quickTip"],@"reconciled pointer exit removes detached quick tooltip even without mouseExited");
    tip=NSView.new; [controller.view addSubview:tip]; [tipButton setValue:tip forKey:@"quickTip"]; tipButton.hidden=YES;
    NSCAssert(!tip.superview,@"hiding a recycled archive action removes its tooltip");
    extern NSString *DPLibraryRemainingTime(long long);
    NSCAssert([DPLibraryRemainingTime(59) isEqual:@"59 sec remaining"] && [DPLibraryRemainingTime(60) isEqual:@"1 min remaining"] && [DPLibraryRemainingTime(3660) isEqual:@"1 hr 1 min remaining"] && [DPLibraryRemainingTime(90000) isEqual:@"1 d 1 hr remaining"],@"ETA formats seconds, minutes, hours and days");
    [controller close];
    NSCollectionViewItem *obsolete = [controller collectionView:controller.collection itemForRepresentedObjectAtIndexPath:[NSIndexPath indexPathForItem:999 inSection:0]];
    NSCAssert(obsolete.view.hidden,@"an obsolete AppKit index is harmless");
    NSCAssert(![controller tableView:controller.table shouldSelectRow:999],@"an obsolete table index is not selectable");
    NSLog(@"PASS: 60 Media/search/Archive/reopen cycles, separate snapshots and obsolete AppKit indexes");
} }
