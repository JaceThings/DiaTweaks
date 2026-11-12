#import "StdPatch/Hide.h"

extern DPPatch DPTurnOffAI;

BOOL DPIsAITitle(NSString *title);

// Dia still counts the hidden suggestions in the command bar.
CGFloat DPHiddenSuggestionsHeight(NSView *suggestions);

void DPInstallAIRows(void);
void DPApplyAIRows(void);
