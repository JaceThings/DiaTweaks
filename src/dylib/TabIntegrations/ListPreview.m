#import "ListPreview.h"
#import "ListRows.h"

@interface DPIntegrationListView : NSView
@end
@implementation DPIntegrationListView
- (BOOL)isFlipped { return YES; }
@end

@interface DPTabIntegrationListPreview ()
@property(nonatomic, copy) id displayedSignature;
@property(nonatomic, strong) DPTabIntegrationListContent *displayedContent;
@end

@implementation DPTabIntegrationListPreview
- (void)loadView { self.view = [[DPIntegrationListView alloc] initWithFrame:NSMakeRect(0, 0, 280, 120)]; }

- (DPTabIntegrationListContent *)listContent {
    return [[DPTabIntegrationListContent alloc] initWithTitle:@"" items:@[]];
}

- (void)performListAction:(NSButton *)sender {
    DPIntegrationListPerformAction(sender, self.context);
}
- (void)performListMenuAction:(NSMenuItem *)sender {
    DPIntegrationListPerformMenuAction(sender, self.context);
}

- (void)activateListItem:(DPTabIntegrationItem *)item {
    BOOL cached = [self.displayedSignature[1] isEqual:@"cached"];
    if (item.primaryAction.enabled && (!cached || item.primaryAction.enabledWhenCached) && item.primaryAction.handler)
        item.primaryAction.handler(self.context, item);
}

- (void)update {
    if (!self.isViewLoaded) return;
    DPTabIntegrationListContent *content = DPIntegrationListSafeContent([self listContent]);
    NSTimeInterval elapsed = NSDate.timeIntervalSinceReferenceDate - self.startedAt;
    NSString *emptyMessage = content.emptyMessage ?: DPTabIntegrationDefaultEmptyMessage(content.state, elapsed);
    NSArray *signature = DPIntegrationListSignature(content, emptyMessage);
    if ([self.displayedSignature isEqual:signature]) return;
    self.displayedSignature = signature;
    self.displayedContent = content;
    for (NSView *child in self.view.subviews.copy) [child removeFromSuperview];

    NSTextField *header = [NSTextField labelWithString:content.title ?: @""];
    header.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    header.frame = NSMakeRect(16, 12, 180, 20);
    header.lineBreakMode = NSLineBreakByTruncatingTail;
    header.toolTip = header.stringValue;
    [self.view addSubview:header];
    NSString *status = content.statusText ?: ([content.state isEqualToString:@"cached"] ? @"Cached" : nil);
    if (status.length) {
        NSTextField *label = [NSTextField labelWithString:status];
        label.font = [NSFont systemFontOfSize:11];
        label.textColor = NSColor.secondaryLabelColor;
        label.alignment = NSTextAlignmentRight;
        label.frame = NSMakeRect(204, 14, 60, 16);
        label.lineBreakMode = NSLineBreakByTruncatingTail; label.toolTip = label.stringValue;
        [self.view addSubview:label];
    }

    CGFloat y = 38;
    BOOL cached = [content.state isEqualToString:@"cached"];
    for (DPTabIntegrationItem *item in content.items ?: @[]) {
        CGFloat rowHeight = item.subtitle.length ? 48 : 36;
        NSView *row = item.viewProvider ? item.viewProvider(item, self.context) : nil;
        if (row) {
            CGFloat customHeight = row.fittingSize.height;
            if (!isfinite(customHeight) || customHeight <= 0) customHeight = row.frame.size.height;
            if (isfinite(customHeight) && customHeight > 0) rowHeight = MAX(rowHeight, customHeight);
        } else row = DPIntegrationListMakeRow(item, self, cached, rowHeight);
        row.frame = NSMakeRect(12, y, 256, rowHeight);
        [self.view addSubview:row];
        y += rowHeight;
        if (item.pinned) {
            NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(16, y + 3, 248, 1)];
            line.boxType = NSBoxSeparator;
            [self.view addSubview:line];
            y += 10;
        }
    }

    if (!content.items.count) {
        NSTextField *empty = [NSTextField wrappingLabelWithString:emptyMessage];
        empty.font = [NSFont systemFontOfSize:12];
        empty.textColor = NSColor.secondaryLabelColor;
        empty.frame = NSMakeRect(16, y + 4, 248, 36);
        [self.view addSubview:empty];
        y += 44;
    }
    if (content.footerMessage.length) {
        NSTextField *footer = [NSTextField wrappingLabelWithString:content.footerMessage];
        footer.font = [NSFont systemFontOfSize:11];
        footer.textColor = NSColor.secondaryLabelColor;
        footer.frame = NSMakeRect(16, y + 4, 248, 32);
        [self.view addSubview:footer];
        y += 36;
    }
    self.preferredContentSize = DPIntegrationListFitContent(self.view, y + 10, content.maximumHeight);
    [self.view setFrameSize:self.preferredContentSize];
}
@end
