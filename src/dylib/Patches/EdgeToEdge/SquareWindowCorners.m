#import "EdgeToEdge.h"

// The page's corners at the window's edge go square, so the window's own corners round them. Where Dia's radius and
// the window's differ, a wedge of the window's color shows behind a rounded page. The squaring is in SquareCorners.m.

static NSString *DPVerifySquareWindowCorners(DPPatch *patch) {
    for (NSView *container in DPFindViews(DPDiaContentContainer)) {
        CALayer *layer = DPRoundedContent(container).layer;
        if (!layer) return @"no rounded web content found";
        if (DPChatCard(container) || DPFullScreen(container)) continue;
        BOOL square = patch->on && DPEdgeToEdge.on;
        NSString *problem = square ? @"corners at the window's edge are round" : @"corners at the window's edge are square";
        if (DPCornersRound(layer, YES) == square) return problem;
        if (!DPBesideSidebar(container) && DPCornersRound(layer, NO) == square) return problem;
    }
    return nil;
}

DP_PATCH(DPSquareWindowCorners) {
    .key = @"squareWindowCorners",
    .order = 21,
    .title = @"Square Corners at Window Edge",
    .detail = @"Square the page's corners where they meet the window's edge, so no gap of the window's color shows behind them.",
    .symbol = @"squareshape",
    .tint = @"systemBlueColor",
    .requires = @"edgeToEdge",
    .verify = DPVerifySquareWindowCorners,
};
