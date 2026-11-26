#import "MediaControls.h"

@implementation DPMediaItem
@end

// A tab goes to the front each time it starts playing. Paused tabs keep their place; tabs no longer reported, because
// they closed or their media ended, drop out.
@implementation DPMediaStack {
    NSMutableArray *_order;  // Tabs, most recently started first.
    NSMutableSet *_playing, *_dismissed;
    NSMutableArray<DPMediaItem *> *_shown;
}

- (instancetype)init {
    if (!(self = [super init])) return nil;
    _order = [NSMutableArray new];
    _playing = [NSMutableSet new];
    _dismissed = [NSMutableSet new];
    _shown = [NSMutableArray new];
    return self;
}

- (void)updateWithItems:(NSArray<DPMediaItem *> *)items selectedTab:(id)selected {
    NSMapTable *byTab = [NSMapTable strongToStrongObjectsMapTable];
    NSMutableSet *playing = [NSMutableSet new];
    for (DPMediaItem *item in items) {
        if (!item.tab) continue;
        [byTab setObject:item forKey:item.tab];
        if (item.playing) [playing addObject:item.tab];
        BOOL started = item.playing && ![_playing containsObject:item.tab];
        if (started) {
            [_order removeObject:item.tab];
            [_order insertObject:item.tab atIndex:0];
            [_dismissed removeObject:item.tab];
        } else if (![_order containsObject:item.tab]) {
            [_order addObject:item.tab];
        }
    }
    [_order filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id tab, NSDictionary *_) { return [byTab objectForKey:tab] != nil; }]];
    [_dismissed intersectSet:[NSSet setWithArray:_order]];
    _playing = playing;
    [_shown removeAllObjects];
    for (id tab in _order)
        if (tab != selected && ![_dismissed containsObject:tab]) [_shown addObject:[byTab objectForKey:tab]];
}

- (void)dismiss:(id)tab {
    if (!tab) return;
    [_dismissed addObject:tab];
    [_shown filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(DPMediaItem *item, NSDictionary *_) { return item.tab != tab; }]];
}

- (NSArray<DPMediaItem *> *)visible { return [_shown subarrayWithRange:NSMakeRange(0, MIN(2, _shown.count))]; }
- (NSUInteger)count { return _shown.count; }

@end
