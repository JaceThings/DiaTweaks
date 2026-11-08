#import "StdPatch/StdPatch.h"

extern DPPatch DPProfileEmoji;
extern NSString *const DPSymbolPrefix;  // Saved icons starting with it name an SF Symbol; the rest are emoji.

NSString *DPSavedIcon(NSString *spaceID);
void DPSaveIcon(NSString *spaceID, NSString *icon);  // nil removes it.
void DPAddEmojiRow(NSViewController *pane);
