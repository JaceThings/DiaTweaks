#import "LittleDia.h"

static const CGFloat DPLittleCornerRadius = 12;
static const NSTimeInterval DPLittleShimmerDuration = 1.1;

// The window-shaped card the transition animates, with the site's name in the middle.
CALayer *DPLittleCard(NSRect frame, NSScreen *screen, NSString *label) {
    CALayer *card = [CALayer layer];
    card.frame = frame;
    card.cornerRadius = DPLittleCornerRadius;
    card.cornerCurve = kCACornerCurveContinuous;
    card.borderWidth = 0.5;
    card.shadowOpacity = 0.28;
    card.shadowRadius = 24;
    card.shadowOffset = CGSizeMake(0, -10);
    CATextLayer *text = [CATextLayer layer];
    text.string = label ?: @"";
    text.fontSize = 13;
    text.alignmentMode = kCAAlignmentCenter;
    text.contentsScale = screen.backingScaleFactor;
    text.frame = CGRectMake(0, CGRectGetHeight(card.bounds) / 2 - 9, CGRectGetWidth(card.bounds), 18);
    [NSApp.effectiveAppearance performAsCurrentDrawingAppearance:^{
        card.backgroundColor = NSColor.windowBackgroundColor.CGColor;
        card.borderColor = NSColor.separatorColor.CGColor;
        text.foregroundColor = NSColor.secondaryLabelColor.CGColor;
    }];
    [card addSublayer:text];
    if (!label) return card;
    // A thin bar sweeps along the top while the page loads behind the card.
    CAGradientLayer *shimmer = [CAGradientLayer layer];
    shimmer.frame = CGRectMake(DPLittleCornerRadius, CGRectGetHeight(card.bounds) - 2, CGRectGetWidth(card.bounds) - 2 * DPLittleCornerRadius, 2);
    shimmer.startPoint = CGPointMake(0, 0.5);
    shimmer.endPoint = CGPointMake(1, 0.5);
    NSColor *accent = NSColor.controlAccentColor;
    shimmer.colors = @[(__bridge id)[accent colorWithAlphaComponent:0].CGColor, (__bridge id)accent.CGColor, (__bridge id)[accent colorWithAlphaComponent:0].CGColor];
    CABasicAnimation *sweep = [CABasicAnimation animationWithKeyPath:@"locations"];
    sweep.fromValue = @[@-0.3, @-0.15, @0];
    sweep.toValue = @[@1, @1.15, @1.3];
    sweep.duration = DPLittleShimmerDuration;
    sweep.repeatCount = HUGE_VALF;
    sweep.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
    [shimmer addAnimation:sweep forKey:@"sweep"];
    [card addSublayer:shimmer];
    return card;
}
