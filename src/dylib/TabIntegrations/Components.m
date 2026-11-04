#import "Components.h"

@implementation DPTabIntegrationAction
- (instancetype)initWithTitle:(NSString *)title handler:(DPTabIntegrationActionHandler)handler {
    if ((self = [super init])) {
        _title = [title copy] ?: @"Action";
        _handler = [handler copy];
        _enabled = YES;
    }
    return self;
}
@end

@implementation DPTabIntegrationItem
- (instancetype)initWithTitle:(NSString *)title {
    if ((self = [super init])) {
        _title = [title copy] ?: @"";
        _actions = @[];
    }
    return self;
}
@end

@implementation DPTabIntegrationListContent
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<DPTabIntegrationItem *> *)items {
    if ((self = [super init])) {
        _title = [title copy] ?: @"";
        _items = [items copy] ?: @[];
        _state = @"live";
        _maximumHeight = 420;
    }
    return self;
}
@end

NSString *DPTabIntegrationDefaultEmptyMessage(NSString *state, NSTimeInterval elapsed) {
    if ([state isEqualToString:@"loading"])
        return elapsed < 6 ? @"Loading…" : @"Data is unavailable. Try again in a moment.";
    if ([state isEqualToString:@"unavailable"])
        return @"Data is unavailable. Try again in a moment.";
    if ([state isEqualToString:@"signedOut"])
        return @"Sign in to view this data.";
    if ([state isEqualToString:@"unsupported"])
        return @"This view is not supported on this page.";
    return @"Nothing to show yet.";
}
