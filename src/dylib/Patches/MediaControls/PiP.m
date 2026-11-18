#import "MediaControls.h"

extern DPPatch DPMediaAfterPiP;
static char DPPiPKey;

BOOL DPMediaWaitsForPiP(id contents) { return DPMediaAfterPiP.on && [DPGet(contents, &DPPiPKey) boolValue]; }

// Dia shows a playing video in picture in picture as you leave its tab, and hides it as you come back or close it.
static void DPWC_showPiP(id self, SEL _cmd, id contents) {
    DPCallOriginal(DPWC_showPiP, self, contents);
    DPMediaRecord(contents, &DPPiPKey, @YES);
}
static void DPWC_hidePiP(id self, SEL _cmd, id contents) {
    DPCallOriginal(DPWC_hidePiP, self, contents);
    DPMediaRecord(contents, &DPPiPKey, @NO);
}
static void DPWC_closePiP(id self, SEL _cmd, id contents) {
    DPCallOriginal(DPWC_closePiP, self, contents);
    DPMediaRecord(contents, &DPPiPKey, @NO);
}

void DPInstallMediaPiP(void) {
    DPHook(DPDiaWebContent, @selector(webContentsShowPiP:), (IMP)DPWC_showPiP);
    DPHook(DPDiaWebContent, @selector(webContentsHidePiP:), (IMP)DPWC_hidePiP);
    DPHook(DPDiaWebContent, @selector(webContentsClosePiP:), (IMP)DPWC_closePiP);
}
