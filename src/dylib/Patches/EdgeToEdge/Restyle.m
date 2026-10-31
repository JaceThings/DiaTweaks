// Dia restyles the page's layers after its own layout and when Chat opens, so the patches restyle after it.
#import "EdgeToEdge.h"

static char DPChatKey;

void DPRestyleContainer(NSView *container) {
    DPApplySquareCorners(container);
    CALayer *card = DPChatCard(container).layer;
    if (!card) return;
    if (card.cornerCurve != kCACornerCurveContinuous) card.cornerCurve = kCACornerCurveContinuous;
    NSValue *requested = DPRequestedFrame(container);
    if (requested && !NSEqualRects(container.frame, requested.rectValue)) container.frame = requested.rectValue;
}

static void DPContainer_layoutOrUpdateLayer(NSView *self, SEL _cmd) {
    DPCallOriginal(DPContainer_layoutOrUpdateLayer, self);
    DPRestyleContainer(self);
    dispatch_async(dispatch_get_main_queue(), ^{ DPRestyleContainer(self); });
}

// Opening or closing Chat reshapes the content without resizing the container.
static void DPShadow_layout(NSView *self, SEL _cmd) {
    DPCallOriginal(DPShadow_layout, self);
    NSView *container = self;
    while (container && !DPIsKind(container, DPDiaContentContainer)) container = container.superview;
    if (!container) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        BOOL chat = DPChatCard(container) != nil;
        if ([DPGet(container, &DPChatKey) boolValue] != chat) {
            DPSet(container, &DPChatKey, @(chat));
            NSValue *requested = DPRequestedFrame(container);
            if (requested) container.frame = requested.rectValue;
        }
        DPRestyleContainer(container);
    });
}

void DPInstallRestyle(void) {
    DPHook(DPDiaContentContainer, @selector(layout), (IMP)DPContainer_layoutOrUpdateLayer);
    DPHook(DPDiaContentContainer, @selector(updateLayer), (IMP)DPContainer_layoutOrUpdateLayer);
    DPHook(DPDiaShadowView, @selector(layout), (IMP)DPShadow_layout);
}
