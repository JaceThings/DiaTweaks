#import "StdPatch/StdPatch.h"

#define DPPiPContentClass "_TtC16PictureInPicture16PIPWindowContent"
#define DPPiPOverlayClass "_TtC16PictureInPicture18PIPOverlayHostView"

extern DPPatch DPPiPIconOnly, DPPiPSmallPlayPause, DPPiPHideDomain;
void DPApplyPiP(DPPatch *patch);
NSString *DPVerifyPiP(DPPatch *patch);
void DPInstallPiPLayout(void);

// Swift reads the existing PiP player and resolves its native actions when a control is pressed.
bool DPPiPShowControls(void *view, bool icons, bool small, bool hideDomain);
void DPPiPRemoveControls(void *view);
bool DPPiPHasControls(void *view);
int32_t DPPiPControlSupport(void *view);
