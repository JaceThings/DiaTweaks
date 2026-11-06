// Media Controls keeps a small player at the bottom of the sidebar for tabs playing in the background, like Arc's. The
// tabs report their sound and media session through Dia's web contents callbacks; the player runs the page's own
// media actions, the ones the keyboard's media keys use.
#import "StdPatch/StdPatch.h"
#import <objc/message.h>

// An object-returning getter Dia doesn't declare to us, and a title that may come back as a string or a URL.
static inline id DPMediaGet(id object, SEL sel) { return object ? ((id (*)(id, SEL))objc_msgSend)(object, sel) : nil; }
static inline NSString *DPMediaText(id value) {
    if ([value isKindOfClass:NSURL.class]) return ((NSURL *)value).absoluteString;
    return [value isKindOfClass:NSString.class] ? value : nil;
}

// One tab with media, as the source reports it.
@interface DPMediaItem : NSObject
@property (nonatomic, strong) id tab;  // The tab's ArcWebContents, compared by identity.
@property (nonatomic, copy) NSString *title, *host;
@property (nonatomic, strong) NSImage *favicon;
@property (nonatomic) BOOL playing, muted, canPrevious, canNext;
@end

// Model.m: which of a window's media tabs get a card, most recent first. One per window.
@interface DPMediaStack : NSObject
- (void)updateWithItems:(NSArray<DPMediaItem *> *)items selectedTab:(id)selected;  // The window's current state.
- (void)dismiss:(id)tab;  // Gone until the tab plays again.
@property (nonatomic, readonly) NSArray<DPMediaItem *> *visible;  // At most two.
@property (nonatomic, readonly) NSUInteger count;                 // How many would show, for the peek.
@end

// Source.m: what the tabs report, and their media actions.
typedef NS_ENUM(NSInteger, DPMediaAction) { DPMediaPlayPause, DPMediaPrevious, DPMediaNext, DPMediaToggleMute, DPMediaSelect };
NSArray<DPMediaItem *> *DPMediaItemsInWindow(NSWindow *window);  // Tabs with media in that window, any profile.
id DPSelectedTab(NSWindow *window);                                // Tabs.m: the media tab on screen in it, if any.
void DPMediaPerform(DPMediaItem *item, DPMediaAction action);
void DPInstallMediaSource(void (^changed)(NSWindow *window));  // `changed` runs once per window after a burst of changes.
extern char DPMediaMutedKey, DPMediaVolumeKey;  // What the tab last reported, on its ArcWebContents.
extern char DPMediaMutedByCardKey;               // Set while the card's own mute holds the tab silent.
void DPMediaRefresh(id contents);                // Redraws the cards of the tab's window.
void DPMediaRecord(id contents, const void *key, id value);  // Keeps what a tab reported, then redraws its cards.
BOOL DPMediaHasMedia(id contents);  // It has reported media it can still play: playing, or paused with a session.
NSArray *DPMediaTabs(void);         // Every tab that has reported media.

// Tabs.m: which window each tab is in, and redrawing as tabs are switched or renamed.
void DPInstallMediaTabs(void);
id DPMediaBrowserOf(id tab);
NSWindow *DPMediaWindowOf(id tab);

// PiP.m: while the option is on, a tab's card waits for its picture in picture window to close.
void DPInstallMediaPiP(void);
BOOL DPMediaWaitsForPiP(id contents);
