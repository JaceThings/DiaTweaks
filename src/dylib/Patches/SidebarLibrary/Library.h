#import "StdPatch/StdPatch.h"
#import "Sections.h"

extern DPPatch DPSidebarLibrary, DPSidebarLibraryRecent, DPSidebarLibraryDust;
extern NSNotificationName const DPLibraryDownloadsChanged;
@interface DPLibraryFile : NSObject
@property(copy) NSString *identifier, *path, *source, *title, *spaceID, *profile;
@property(readonly) NSString *key;
@property BOOL archived, missing;
@property NSDate *date;
@property NSInteger state;
@property long long completed, total;
@property long long remaining;
@property BOOL paused;
@end

@protocol DPLibraryAnimation <NSObject>
- (void)stopAnimation;
@end
@interface DPLibraryController : NSObject
@property id activationObserver;
@property(weak) NSWindow *window;
@property(copy) NSString *context;
@property(copy) NSString *spaceID;
@property NSView *view;
@property(weak) NSView *sidebarHost, *pageHost, *backdrop;
@property CGFloat expandedWidth, originalWidth;
@property BOOL expanded, ownsHost, interacting;
@property CGFloat expansion;
@property id<DPLibraryAnimation> motion;
@property NSMutableArray<NSView *> *coveredViews;
@property id downloadsObserver;
@property id sectionsObserver;
@property NSView *customContent;
@property NSString *customSection;
@property NSButton *sectionAction;
@property NSArray<NSButton *> *customHeaderButtons;
@property(weak) NSResponder *preferredSectionResponder;
@property NSSharingServicePicker *sharingPicker;
@property id previewSource;
@property NSView *rail;
@property NSColor *lastAccent;
@property CFTimeInterval lastAccentCheck;
@property NSView *searchChrome, *filterChrome;
@property NSButton *refresh;
@property BOOL dragging, reloadAfterDrag, showHidden, removing,animateRemoval;
@property NSButton *options;
@property NSView *sectionHighlight, *contentChrome;
@property NSString *layoutSignature;
@property NSInteger filterIndex;
@property NSRect backAnchor;
@property BOOL hasBackAnchor;
@property NSSearchField *search;
@property NSPopUpButton *filter;
@property NSScrollView *scroll, *mediaScroll;
@property NSTableView *table;
@property NSCollectionView *collection;
@property NSTextField *empty;
@property(copy) NSArray<DPLibraryFile *> *files, *archive, *mediaFiles;
@property NSArray *rows, *listingState;
@property NSUInteger archiveGeneration;
@property NSString *section;
@property(weak) NSResponder *previousResponder;
@property BOOL closing;
- (instancetype)initWithWindow:(NSWindow *)window context:(id)context;
- (void)show;
- (void)showAnimated:(BOOL)animated;
- (void)close;
- (void)layout;

@end

NSImage *DPLibraryEntryImage(void);
NSString *DPLibraryActiveSpace(NSWindow *window);
void DPLibraryBuildInputSurfaces(DPLibraryController *controller);
id DPLibraryNativeContext(NSString *profile);
void DPLibraryFavicon(NSString *profile,NSString *source,void (^completion)(NSImage *));
NSString *DPLibraryFileDetail(DPLibraryFile *file);
@interface DPLibraryMediaView : NSView
@property(weak) NSImageView *imageView;
@property BOOL hovered, chosen;
- (void)refreshImage;
- (NSImage *)framedImage;
- (NSRect)framedRect;
- (void)resetHover;
@end


@interface DPLibraryController (Refresh)
- (void)refreshLibrary:(id)sender;
@end
@interface DPLibraryController (Items)
- (void)displayFiles:(NSArray<DPLibraryFile *> *)files media:(BOOL)media;
@end
@interface DPLibraryController (Reload) <NSSearchFieldDelegate>
- (void)reload;
@end
@interface DPLibraryController (Build)
- (void)build;
- (void)chooseSection:(NSButton *)sender;
@end
@interface DPLibraryController (FileRows) <NSTableViewDataSource,NSTableViewDelegate>
- (void)updateFileCell:(NSTableCellView *)cell file:(DPLibraryFile *)file loadImage:(BOOL)loadImage;
- (void)openSelection:(id)sender;
- (void)revealSelection:(id)sender;
@end
@interface DPLibraryController (QuickLook)
- (void)quickLook:(id)sender;
@end
@interface DPLibraryController (Media) <NSCollectionViewDataSource,NSCollectionViewDelegate,NSCollectionViewDelegateFlowLayout> @end
@interface DPLibraryController (FileMenu)
- (NSArray<DPLibraryFile *> *)selectedFiles;
- (NSArray<NSURL *> *)selectedFileURLs;
- (NSMenu *)fileMenu;
- (void)hideSelection:(id)sender;
- (void)copy:(id)sender;
- (void)shareSelection:(id)sender;
@end

@interface DPLibraryButton : NSButton
@property BOOL hovered;
@property NSTrackingArea *tracking;
@end
@interface DPLibraryMediaItem : NSCollectionViewItem @end

BOOL DPLibraryCanOpenArchivedURL(NSURL *url);
NSArray<DPLibraryFile *> *DPLibraryParseArchive(NSData *data, NSString *profile);
void DPLibraryLoadArchive(NSString *profile, void (^completion)(NSArray<DPLibraryFile *> *));
void DPLibraryInstallDownloads(void);
NSArray<DPLibraryFile *> *DPLibraryFiles(id context);
id DPLibraryContextForWindow(NSWindow *window);
NSArray *DPLibraryDateSections(NSArray<DPLibraryFile *> *files,NSDate *now);
BOOL DPLibraryIsMedia(DPLibraryFile *file);
NSArray<DPLibraryFile *> *DPLibraryFiltered(NSArray<DPLibraryFile *> *files, NSString *query, NSInteger filter, BOOL media);
void DPLibraryHideFiles(id context, NSArray<DPLibraryFile *> *files);
void DPLibraryThumbnail(NSURL *url, void (^completion)(NSImage *));
NSButton *DPLibraryMakeButton(NSString *title, NSString *symbol, id target, SEL action);
BOOL DPLibraryMount(DPLibraryController *controller);
NSRect DPLibraryNativeFrame(NSView *view);
void DPLibraryAnimate(DPLibraryController *controller,BOOL opening);
void DPLibraryUpdateHosts(DPLibraryController *controller);
void DPLibraryCoverTabs(DPLibraryController *controller);
void DPLibraryUncoverTabs(DPLibraryController *controller);
void DPLibraryUnmount(DPLibraryController *controller);
void DPLibraryTogglePreview(DPLibraryController *controller,NSResponder *responder);
void DPLibraryClosePreview(DPLibraryController *controller);
void DPLibraryDismissForWindow(NSWindow *window);
void DPLibraryToggle(NSWindow *window);
void DPLibraryRefreshFooters(void);
void DPLibraryInstallFooter(void);

NSColor *DPLibraryAccentColor(NSWindow *window);
NSButton *DPLibraryMakeEntryButton(NSString *identifier);
void DPLibraryInstallHorizontal(void);
void DPLibraryRefreshHorizontal(void);
void DPLibraryUpdateBackdrop(DPLibraryController *controller);
NSString *DPLibraryVerifyHorizontal(BOOL enabled);
NSButton *DPLibraryMakeRefreshButton(id target,SEL action);
void DPLibraryAnimateRefresh(NSButton *button);
DPLibraryController *DPLibraryBeginInteraction(NSWindow *window);
void DPLibraryUpdateInteractiveLayout(DPLibraryController *controller);
void DPLibraryEndInteractiveLayout(DPLibraryController *controller);
void DPLibraryMoveCoveredTabs(DPLibraryController *controller,CGFloat offset);
void DPLibraryRestoreCoveredMotion(DPLibraryController *controller);

NSSet *DPLibraryHiddenIDs(NSString *profile,BOOL archive);
void DPLibrarySetHidden(NSString *profile,NSArray<DPLibraryFile *> *files,BOOL hidden);
void DPLibraryRestoreHidden(NSString *profile,BOOL archive);
NSArray<DPLibraryFile *> *DPLibraryAllFiles(id context);
void DPLibraryDissolve(NSArray<NSView *> *views,void (^completion)(void));
void DPLibraryUpdateChrome(DPLibraryController *owner);
void DPLibraryMoveSectionHighlight(DPLibraryController *owner,BOOL animated);
void DPLibraryResetUtilityHover(NSWindow *window);
@interface DPLibraryController (Actions)
- (void)showOptions:(id)sender;
- (void)restoreSelection:(id)sender;
- (void)trashSelection:(id)sender;
- (void)copyImage:(id)sender;
- (void)showDownloadMenu:(NSButton *)sender;
- (void)reopenArchive:(NSButton *)sender;
- (void)hideArchive:(NSButton *)sender;
@end

NSArray<DPLibraryFile *> *DPLibrarySharedMediaFiles(BOOL hidden);
NSUInteger DPLibraryHiddenMediaCount(void);
void DPLibraryRestoreHiddenMedia(void);
BOOL DPLibraryPointerInside(NSView *view);
void DPLibraryReconcileHover(NSView *root);

NSPopUpButton *DPLibraryMakeFilterButton(id target,SEL action);
