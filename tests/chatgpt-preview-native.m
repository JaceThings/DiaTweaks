#import "Patches/ChatGPTPreview/ChatGPTPreview.h"

int main(void) {
    @autoreleasepool {
        NSCAssert(DPChatGPTURL(@"https://chatgpt.com/c/session"), @"ChatGPT URL");
        NSCAssert(DPChatGPTURL((id)[NSURL URLWithString:@"https://chatgpt.com/"]), @"NSURL from native contents");
        for (NSString *url in @[@"http://chatgpt.com/", @"https://chatgpt.com.evil.test/", @"https://other.test/", @"https://u:p@chatgpt.com/", @"https://chatgpt.com:444/"])
            NSCAssert(!DPChatGPTURL(url), @"reject foreign origins and credentials");
        NSCAssert(!DPChatGPTURL((id)NSNull.null), @"reject malformed URL values");
        NSCAssert([DPChatGPTConversationURL(@"conversation-123") isEqual:@"https://chatgpt.com/c/conversation-123"], @"conversation destination");
        for (NSString *identifier in @[@"", @"../x", @"id?q=x", @"id#fragment", @"//evil.test", @"a/b"])
            NSCAssert(!DPChatGPTConversationURL(identifier), @"never navigate to supplied paths");
        NSCAssert([DPTabIntegrationDecode(@"{\"recent\":[]}")[@"recent"] isKindOfClass:NSArray.class], @"direct JSON result");
        NSCAssert([DPTabIntegrationDecode(@"\"{\\\"recent\\\":[]}\"")[@"recent"] isKindOfClass:NSArray.class], @"Chromium serializes a string result again");
        NSCAssert(!DPTabIntegrationDecode(@"[1,2]"), @"not a snapshot object");
        NSCAssert(!DPTabIntegrationDecode(@"undefined"), @"failed JavaScript result");
        NSCAssert(!DPTabIntegrationDecode([@"x" stringByPaddingToLength:300000 withString:@"x" startingAtIndex:0]), @"bound native transport payload");
        NSString *multibyte = [@"雪" stringByPaddingToLength:90000 withString:@"雪" startingAtIndex:0];
        NSCAssert(!DPTabIntegrationDecode([NSString stringWithFormat:@"{\"title\":\"%@\"}", multibyte]), @"transport limit counts UTF-8 bytes");

        [NSApplication sharedApplication];
        __block NSInteger opened = 0, pinned = 0;
        NSView *row = DPChatGPTConversationRow(@{@"id":@"a", @"title":@"Example conversation", @"activity":@"generating", @"unread":@YES}, NO, ^{ opened++; }, ^{ pinned++; });
        NSProgressIndicator *spinner;
        NSInteger unreadDots = 0;
        for (NSView *child in row.subviews) {
            NSCAssert(NSContainsRect(row.bounds, child.frame), @"compact row keeps title, status and pin within its bounds");
            if ([child isKindOfClass:NSProgressIndicator.class]) spinner = (NSProgressIndicator *)child;
            if ([child.accessibilityLabel isEqual:@"Unread"]) unreadDots++;
            if (![child isKindOfClass:NSButton.class]) continue;
            NSButton *button = (NSButton *)child;
            [button performClick:nil];
        }
        NSCAssert(spinner && unreadDots == 0, @"working takes precedence over the completion dot");
        NSCAssert(opened == 1 && pinned == 1, @"navigation and integration pin have distinct actions");
        NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 400, 200)];
        [container addSubview:row];
        [row setFrameOrigin:NSMakePoint(12, 24)];
        for (NSValue *point in @[[NSValue valueWithPoint:NSMakePoint(2, 18)], [NSValue valueWithPoint:NSMakePoint(100, 18)], [NSValue valueWithPoint:NSMakePoint(224, 18)]])
            NSCAssert([row hitTest:[row convertPoint:point.pointValue toView:container]] == row, @"padding, title and trailing gap share the full-row navigation target");
        NSEvent *click = [NSEvent mouseEventWithType:NSEventTypeLeftMouseDown location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:1];
        [row mouseDown:click];
        NSCAssert(opened == 2, @"clicking row padding opens the conversation");
        NSView *pinTarget = [row hitTest:[row convertPoint:NSMakePoint(242, 18) toView:container]];
        NSCAssert([pinTarget isKindOfClass:NSButton.class], @"pin retains its own hit target");
        [(NSButton *)pinTarget performClick:nil];
        NSCAssert(pinned == 2 && opened == 2, @"pin does not also navigate");
        [row updateTrackingAreas];
        NSCAssert(row.trackingAreas.count > 0, @"row installs hover feedback tracking");
        NSEvent *entered = [NSEvent enterExitEventWithType:NSEventTypeMouseEntered location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:0 trackingNumber:0 userData:NULL];
        [row mouseEntered:entered];
        NSCAssert(row.layer.backgroundColor && CGColorGetAlpha(row.layer.backgroundColor) > 0, @"hover highlights the conversation row");
        NSEvent *exited = [NSEvent enterExitEventWithType:NSEventTypeMouseExited location:NSZeroPoint modifierFlags:0 timestamp:0 windowNumber:0 context:nil eventNumber:0 trackingNumber:0 userData:NULL];
        [row mouseExited:exited];
        NSCAssert(CGColorGetAlpha(row.layer.backgroundColor) == 0, @"leaving clears the row highlight");
        [spinner stopAnimation:nil];
        NSView *cachedRow = DPChatGPTConversationRow(@{@"id":@"a", @"title":@"Cached conversation", @"activity":@"stale", @"unread":@NO}, YES, ^{ opened++; }, nil);
        BOOL disabledPin = NO;
        for (NSView *child in cachedRow.subviews)
            if ([child isKindOfClass:NSButton.class] && ((NSButton *)child).action == NSSelectorFromString(@"pinRow:")) {
                disabledPin = !((NSButton *)child).enabled;
                [(NSButton *)child performClick:nil];
            }
        NSCAssert(disabledPin && opened == 2, @"cached preview retains a disabled pin without accidentally navigating");
        for (NSString *title in @[@"Short", [@"Long title " stringByPaddingToLength:300 withString:@"Long title " startingAtIndex:0]])
            for (NSString *activity in @[@"generating", @"idle"]) {
                NSView *layout = DPChatGPTConversationRow(@{@"id":@"layout", @"title":title, @"activity":activity, @"unread":@YES}, NO, ^{}, ^{});
                NSButton *link = nil, *pin = nil;
                NSView *status = nil;
                for (NSView *child in layout.subviews) {
                    if ([child isKindOfClass:NSButton.class]) {
                        if ([((NSButton *)child).toolTip hasPrefix:@"Pin"] || [((NSButton *)child).toolTip hasPrefix:@"Unpin"]) pin = (NSButton *)child;
                        else link = (NSButton *)child;
                    } else status = child;
                }
                NSCAssert(link.frame.origin.x == 4 && link.frame.size.width <= 192, @"leading alignment preserves the previous title limit");
                NSCAssert(status && NSMinX(status.frame) >= NSMaxX(link.frame) + 8, @"status follows the visible title");
                NSCAssert(NSMaxX(status.frame) < NSMinX(pin.frame), @"status cannot overlap the pin even for a long title");
                for (NSView *child in layout.subviews) if ([child isKindOfClass:NSProgressIndicator.class]) [(NSProgressIndicator *)child stopAnimation:nil];
            }
        puts("chatgpt-preview-native: URL boundaries, Chromium results, row actions and status indicators passed");
    }
}
