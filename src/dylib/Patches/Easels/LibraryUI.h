#import "Easels.h"
@class DPLibraryController;
@interface DPEaselCard : NSControl
@property NSDictionary *record;
@property(weak) id owner;
@property(nonatomic) BOOL hovered;
@property BOOL trashed;
@property NSButton *restoreButton;
@property NSTrackingArea *tracking;
- (void)restoreFromMenu:(id)sender;
- (void)reconcileHover;
@end
@interface DPEaselLibraryContent : NSView
@property(weak) DPLibraryController *library;
@property NSScrollView *scroll;
@property NSView *grid;
@property NSTextField *empty;
@property NSImageView *emptyIcon;
@property NSButton *create;
@property NSButton *recovery,*importButton;
@property NSArray<NSDictionary *> *records;
@property NSString *query,*listingSignature,*profile;
@property BOOL loaded, allowed;
@property BOOL showTrash,removing,animateReflow;
@property NSUInteger generation;
@property id changes,scrollChanges;
@property NSUndoManager *undo;
- (void)reload;
- (void)displayRecords;
@end
@interface DPEaselLibraryContent (Actions)
- (void)openCard:(DPEaselCard *)card;
- (void)deleteCard:(DPEaselCard *)card;
- (void)restoreCard:(DPEaselCard *)card;
- (void)toggleTrash:(id)sender;
- (void)importEasel:(id)sender;
- (void)newEasel:(id)sender;
@end
