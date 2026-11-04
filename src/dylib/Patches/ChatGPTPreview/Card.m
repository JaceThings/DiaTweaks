#import "ChatGPTPreview.h"
#import "Cache.h"

@interface DPChatGPTListView : NSView
@end
@implementation DPChatGPTListView
- (BOOL)isFlipped { return YES; }
@end

@implementation DPChatGPTCard
- (void)loadView { self.view = [[DPChatGPTListView alloc] initWithFrame:NSMakeRect(0, 0, 280, 120)]; }
- (void)viewDidLoad {
    [super viewDidLoad];
    self.startedAt = NSDate.timeIntervalSinceReferenceDate;
    __weak DPChatGPTCard *weak = self;
    self.refresh = [NSTimer timerWithTimeInterval:0.5 repeats:YES block:^(NSTimer *_) { [weak update]; }];
    [NSRunLoop.mainRunLoop addTimer:self.refresh forMode:NSRunLoopCommonModes];
    [self update];
}
- (void)stop { [self.refresh invalidate]; self.refresh = nil; }
- (void)dealloc { [self.refresh invalidate]; }

- (NSDictionary *)sessions {
    self.page = DPTabIntegrationPageForTab(self.integration, self.tab);
    return DPChatGPTCachePresentation(DPTabIntegrationCacheForPage(self.page), self.page.snapshot,
                                     self.page.receivedAt, NSDate.timeIntervalSinceReferenceDate);
}

- (void)openSession:(NSString *)identifier {
    NSString *url = DPChatGPTConversationURL(identifier);
    if (!url || !DPChatGPTURL([self.tab valueForKey:@"URL"])) return;
    [self navigateToURL:url];
}

- (void)update {
    if (!self.isViewLoaded) return;
    NSDictionary *data = [self sessions];
    NSArray *rows = data[@"rows"];
    NSDictionary *pinned = data[@"pin"];
    BOOL cached = [data[@"state"] isEqual:@"cached"];
    NSString *message = DPChatGPTEmptyMessage(data[@"state"], NSDate.timeIntervalSinceReferenceDate - self.startedAt);
    NSDictionary *display = @{@"rows":rows, @"pin":pinned, @"state":data[@"state"], @"message":message};
    if ([display isEqual:self.displayed]) return;
    self.displayed = display;
    for (NSView *view in self.view.subviews.copy) [view removeFromSuperview];
    NSTextField *header = [NSTextField labelWithString:@"ChatGPT"];
    header.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    header.frame = NSMakeRect(16, 12, 248, 20);
    [self.view addSubview:header];
    if (cached) {
        NSTextField *label = [NSTextField labelWithString:@"Cached"];
        label.font = [NSFont systemFontOfSize:11];
        label.textColor = NSColor.secondaryLabelColor;
        label.alignment = NSTextAlignmentRight;
        label.frame = NSMakeRect(204, 14, 60, 16);
        [self.view addSubview:label];
    }
    CGFloat y = 38;
    __weak DPChatGPTCard *weak = self;
    for (NSDictionary *row in rows) {
        BOOL isPinned = [row[@"id"] isEqual:pinned[@"id"]];
        NSView *view = DPChatGPTConversationRow(row, isPinned, ^{ [weak openSession:row[@"id"]]; }, cached ? nil : ^{
            DPTabIntegrationCommand(weak.page, @"pin", @[isPinned ? NSNull.null : row[@"id"]]);
        });
        [view setFrameOrigin:NSMakePoint(12, y)];
        [self.view addSubview:view];
        y += 36;
        if (isPinned) {
            NSBox *line = [[NSBox alloc] initWithFrame:NSMakeRect(16, y + 3, 248, 1)];
            line.boxType = NSBoxSeparator;
            [self.view addSubview:line];
            y += 10;
        }
    }
    if (!rows.count) {
        NSTextField *footer = [NSTextField wrappingLabelWithString:message];
        footer.font = [NSFont systemFontOfSize:12];
        footer.textColor = NSColor.secondaryLabelColor;
        footer.frame = NSMakeRect(16, y + 4, 248, 36);
        [self.view addSubview:footer];
        y += 44;
    }
    self.preferredContentSize = NSMakeSize(280, y + 10);
    [self.view setFrameSize:self.preferredContentSize];
}
@end
