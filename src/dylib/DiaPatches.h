#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

typedef struct DPPatch DPPatch;
struct DPPatch {
    __unsafe_unretained NSString *key;
    BOOL defaultOn;
    __unsafe_unretained NSString *title, *detail, *symbol;
    NSColor *(*tint)(void);
    DPPatch *requires;    // Settings shows the row only while this patch is on.
    DPPatch *disabledBy;  // Settings disables the switch while this patch is on.
    void (*install)(void);
    void (*apply)(DPPatch *patch);  // Applies a toggle at once. Without it, `progress` eases toward `on` while every patch's `relayout` runs each frame.
    void (*relayout)(void);
    BOOL on;
    CGFloat progress;
};

extern DPPatch DPEdgeToEdge, DPSquareSidebarCorners, DPHideToolbar, DPHideSidebarButton, DPHideChatButton, DPHideChatsButton, DPHideRecentTabsButton;
extern DPPatch *const DPPatches[];
extern const NSUInteger DPPatchCount;

void DPHook(Class cls, SEL sel, IMP replacement);
IMP DPOriginalIMP(id object, SEL sel);

#define DPCallOriginal(type, object, sel, ...) ((type)DPOriginalIMP(object, sel))(object, sel, ##__VA_ARGS__)

void DPInstallUpdates(void);
void DPRunCLI(NSArray<NSString *> *args, void (^completion)(NSString *output));
void DPCheckForUpdates(void (^completion)(NSDictionary *status));
void DPHandOffAndQuit(NSString *command);
