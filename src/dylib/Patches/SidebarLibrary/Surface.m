#import "Library.h"
@interface DPLibrarySurface : NSView
@property(weak) DPLibraryController *owner;
@end
@implementation DPLibrarySurface
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (void)layout { [super layout]; [self.owner layout]; }
- (void)mouseDown:(NSEvent *)event { [self.window makeFirstResponder:self]; }
- (void)rightMouseDown:(NSEvent *)event {}
@end
@implementation DPLibraryController
- (instancetype)initWithWindow:(NSWindow *)window context:(id)context {
    if ((self = [super init])) {
        self.window = window; self.context = context;
        NSString *section = [[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] stringForKey:@"sidebarLibrarySection"];
        self.section = [DPLibrarySectionNames() containsObject:section] ? section : @"Downloads"; self.files = @[];
        DPLibrarySurface *surface = [[DPLibrarySurface alloc] initWithFrame:NSZeroRect];
        surface.owner = self;
        surface.wantsLayer = YES; surface.layer.cornerRadius = 0; surface.layer.masksToBounds = YES;
        surface.accessibilityLabel = @"Sidebar Library"; self.view = surface;
        [self build];
        __weak DPLibraryController *weak = self;
        self.downloadsObserver = [NSNotificationCenter.defaultCenter addObserverForName:DPLibraryDownloadsChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (weak.view.superview && ([@"Downloads" isEqual:weak.section] || [@"Media" isEqual:weak.section])) [weak reload];
        }];
        self.activationObserver = [NSNotificationCenter.defaultCenter addObserverForName:NSApplicationDidBecomeActiveNotification object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            if (weak.view.superview && ([@"Downloads" isEqual:weak.section] || [@"Media" isEqual:weak.section])) [weak reload];
        }];
        self.sectionsObserver=[NSNotificationCenter.defaultCenter addObserverForName:DPLibrarySectionsChanged object:nil queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note){
            DPLibraryController *owner=weak; if(!owner) return; DPLibraryBuildCategories(owner); [owner reload];
        }];
    }
    return self;
}
- (void)dealloc { if(self.activationObserver) [NSNotificationCenter.defaultCenter removeObserver:self.activationObserver]; [self.motion stopAnimation]; if (self.downloadsObserver) [NSNotificationCenter.defaultCenter removeObserver:self.downloadsObserver]; if(self.sectionsObserver) [NSNotificationCenter.defaultCenter removeObserver:self.sectionsObserver]; }
- (void)show { [self showAnimated:YES]; }
- (void)showAnimated:(BOOL)animated {
    NSView *content = self.window.contentView;
    if (!content || self.view.superview) return;
#ifdef DPLIBRARY_DIAGNOSTICS
    extern void DPLibraryInspectSidebar(NSWindow *window);
    DPLibraryInspectSidebar(self.window);
#endif
    NSResponder *previous = self.window.firstResponder;
    if ([previous isKindOfClass:NSTextView.class] && [(NSTextView *)previous isFieldEditor]) {
        id field = [(NSTextView *)previous delegate];
        previous = [field isKindOfClass:NSResponder.class] ? field : self.window.contentView;
    }
    self.previousResponder = previous; self.listingState = nil;
    self.spaceID = DPLibraryActiveSpace(self.window);
    NSView *entry = DPFindView(content,^BOOL(NSView *view) { return [view.identifier isEqual:@"DiaTweaks.SidebarLibrary.Button"] && !view.hiddenOrHasHiddenAncestor; });
    self.hasBackAnchor = entry != nil; if (entry) self.backAnchor = [entry convertRect:entry.bounds toView:nil];
    // Publish the section's data before attachment can trigger AppKit layout.
    for (NSView *child in self.rail.subviews) if ([child.identifier isEqual:@"category"] && [(NSButton *)child state]) { [self chooseSection:(NSButton *)child]; break; }
    [self reload];
    if (animated) self.interacting = YES;
    if (!DPLibraryMount(self)) { self.interacting = NO; return; }
    self.view.hidden = NO; self.view.alphaValue = 1; [self layout];
    if (animated) { DPLibraryAnimate(self,YES); [self.window makeFirstResponder:self.preferredSectionResponder ?: self.search]; }
    else DPLibraryUpdateHosts(self);
    self.searchChrome.needsDisplay = YES;
}
- (void)close {
    if (!self.expanded || self.closing) return;
    DPLibraryResetUtilityHover(self.window);
    DPLibraryClosePreview(self); self.sharingPicker = nil; DPLibraryAnimate(self,NO);
}
- (void)layout {
    NSView *content = self.window.contentView;
    if (!content) return;
    NSView *host = self.sidebarHost;
    if (!host) return;
    DPLibraryCoverTabs(self);
    NSView *header = DPSubview(host,DPDiaSidebarHeader);
    CGFloat top = header ? NSMaxY(header.frame) : 0;
    CGFloat offset=self.interacting ? self.expandedWidth*(self.expansion-1) : 0;
    NSRect area = NSMakeRect(offset,0,self.interacting ? self.expandedWidth : NSWidth(host.bounds),NSHeight(host.bounds));
    if (!NSEqualRects(self.view.frame,area)) self.view.frame = area;
    NSString *signature=[NSString stringWithFormat:@"%@-%g-%@-%d-%@",NSStringFromSize(area.size),top,self.section,self.hasBackAnchor,NSStringFromRect(self.backAnchor)];
    if ([self.layoutSignature isEqual:signature]) { DPLibraryUpdateInteractiveLayout(self); return; }
    self.layoutSignature=signature;
    DPLibraryUpdateChrome(self);
    CGFloat width = MAX(NSWidth(self.view.bounds),self.expandedWidth), height = NSHeight(self.view.bounds);
    self.rail.frame = NSMakeRect(0,0,88,height);
    BOOL filtering = ![self.section isEqual:@"Media"] && !self.customContent;
    self.searchChrome.frame = NSMakeRect(104,top+14,MAX(80,width-(filtering ? 324 : 194)),36);
    self.filterChrome.frame = NSMakeRect(width-212,top+14,122,36);
    self.search.frame = NSMakeRect(32,9,MAX(20,NSWidth(self.searchChrome.bounds)-40),18);
    self.options.frame = NSMakeRect(width-46,top+17,30,30);
    self.refresh.frame = NSMakeRect(width-82,top+17,30,30);
    self.filter.frame = NSInsetRect(self.filterChrome.bounds,6,4);
    self.scroll.frame = NSMakeRect(96,top+66,MAX(0,width-104),MAX(0,height-top-74));
    self.mediaScroll.frame = self.scroll.frame;
    DPLibraryLayoutCustomSection(self);
    NSSize mediaSize = self.mediaScroll.contentView.bounds.size;
    if (NSWidth(self.collection.frame) != mediaSize.width) {
        [self.collection setFrameSize:NSMakeSize(mediaSize.width,MAX(mediaSize.height,NSHeight(self.collection.frame)))];
        [self.collection.collectionViewLayout invalidateLayout];
    }
    [self.table sizeLastColumnToFit];
    self.empty.frame = NSMakeRect(110,MAX(75,height/2-35),MAX(0,width-130),70);
    for (NSView *child in self.rail.subviews) {
        if ([child.identifier isEqual:@"back"]) child.frame = self.hasBackAnchor ? [host convertRect:self.backAnchor fromView:nil] : NSMakeRect(6,MAX(0,height-38),30,30);
        if ([child.identifier isEqual:@"category"]) child.frame = NSMakeRect(6,MAX(60,(height-DPLibrarySectionNames().count*78)/2)+[(NSButton *)child tag]*78,76,65);
    }
    DPLibraryMoveSectionHighlight(self,NO);
    DPLibraryUpdateInteractiveLayout(self);
}
@end
