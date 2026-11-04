#import "ListRows.h"
#import "ListPreview.h"

void DPIntegrationListPopulateRow(NSView *row, DPTabIntegrationItem *item, DPTabIntegrationListPreview *preview, BOOL cached) {
    NSFont *font = [NSFont systemFontOfSize:13];
    NSUInteger overflow = item.actions.count > 3 ? 1 : 0;
    NSUInteger visibleCount = overflow ? 3 : item.actions.count;
    NSUInteger directCount = overflow ? 2 : visibleCount;
    NSUInteger actionCount = visibleCount;
    CGFloat statusSpace = item.statusText.length ? MIN(72, ceil([item.statusText sizeWithAttributes:@{NSFontAttributeName:[NSFont systemFontOfSize:11]}].width) + 4) : 0;
    CGFloat maxTitleWidth = MAX(32, (actionCount ? 224 - actionCount * 32 : 220) - (statusSpace ? statusSpace + 8 : 0));
    CGFloat titleWidth = MIN(maxTitleWidth, ceil([item.title sizeWithAttributes:@{NSFontAttributeName:font}].width) + 4);
    NSTextField *title = [NSTextField labelWithString:item.title ?: @""];
    title.font = font;
    title.lineBreakMode = NSLineBreakByTruncatingTail;
    title.frame = NSMakeRect(4, item.subtitle.length ? 5 : 9, titleWidth, 18);
    title.toolTip = item.toolTip.length ? item.toolTip : item.title;
    [row addSubview:title];

    if (item.subtitle.length) {
        NSTextField *subtitle = [NSTextField labelWithString:item.subtitle];
        subtitle.font = [NSFont systemFontOfSize:11];
        subtitle.textColor = NSColor.secondaryLabelColor;
        subtitle.lineBreakMode = NSLineBreakByTruncatingTail;
        subtitle.frame = NSMakeRect(4, 25, MAX(32, maxTitleWidth), 16);
        subtitle.toolTip = item.subtitle;
        [row addSubview:subtitle];
    }
    CGFloat statusX = NSMaxX(title.frame) + 8;
    BOOL showWorking = item.working && !cached;
    BOOL showUnread = item.unread && !cached && !showWorking;
    CGFloat detailX = statusX + ((showWorking || showUnread) ? 24 : 0);
    if (showWorking) {
        NSProgressIndicator *spinner = [[NSProgressIndicator alloc] initWithFrame:NSMakeRect(statusX, item.subtitle.length ? 6 : 10, 16, 16)];
        spinner.style = NSProgressIndicatorStyleSpinning;
        spinner.controlSize = NSControlSizeSmall;
        spinner.displayedWhenStopped = NO;
        spinner.accessibilityLabel = @"Working";
        [row addSubview:spinner];
        [spinner startAnimation:nil];
    } else if (showUnread) {
        NSView *dot = [[NSView alloc] initWithFrame:NSMakeRect(statusX + 5, item.subtitle.length ? 11 : 15, 6, 6)];
        dot.wantsLayer = YES;
        dot.layer.cornerRadius = 3;
        dot.layer.backgroundColor = NSColor.systemBlueColor.CGColor;
        dot.accessibilityElement = YES;
        dot.accessibilityLabel = @"Unread";
        [row addSubview:dot];
    }
    if (item.statusText.length) {
        CGFloat detailEnd = actionCount ? 228 - (actionCount - 1) * 32 - 8 : 252;
        CGFloat detailWidth = MAX(0, detailEnd - detailX);
        if (detailWidth > 0) {
            NSTextField *detail = [NSTextField labelWithString:item.statusText];
            detail.font = [NSFont systemFontOfSize:11];
            detail.textColor = NSColor.secondaryLabelColor;
            detail.frame = NSMakeRect(detailX, item.subtitle.length ? 5 : 10, detailWidth, 16);
            detail.lineBreakMode = NSLineBreakByTruncatingTail;
            detail.toolTip = item.statusText;
            [row addSubview:detail];
        }
    }
    for (NSUInteger index = 0; index < directCount; index++) {
        DPTabIntegrationAction *action = item.actions[index];
        CGFloat x = 228 - (actionCount - index - 1) * 32;
        NSButton *button = DPIntegrationListMakeActionButton(action, item, NSMakeRect(x, 4, 28, 28), preview, cached);
        [row addSubview:button];
    }
    if (overflow) {
        CGFloat x = 228;
        NSButton *more = DPIntegrationListMakeMoreActionsButton([item.actions subarrayWithRange:NSMakeRange(directCount, item.actions.count - directCount)],
            item, NSMakeRect(x, 4, 28, 28), preview, cached);
        [row addSubview:more];
    }
}
