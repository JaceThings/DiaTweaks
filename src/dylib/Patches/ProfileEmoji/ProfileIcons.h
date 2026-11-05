#import "StdPatch/StdPatch.h"

extern DPPatch DPProfileEmoji;
extern NSUserDefaults *DPEmojiDefaults;
NSString *DPProfileEmojiValue(NSString *spaceID);
NSString *DPProfileSymbolName(NSString *spaceID);
NSString *DPProfilePreferredSymbolName(NSString *name);
NSImage *DPProfileSymbolImage(NSString *name, CGFloat size);
BOOL DPProfileHasIcon(NSString *spaceID);
void DPStoreProfileIcon(NSString *spaceID, NSString *emoji, NSString *symbol);
void DPRefreshProfileIcons(void);
void DPTrackProfilePane(NSViewController *pane);
void DPUpdateProfilePanes(void);

@interface DPProfileIconPicker : NSViewController <NSSearchFieldDelegate>
@property(copy) void (^selection)(NSString *name);
@property(copy) NSString *selectedName;
@end
