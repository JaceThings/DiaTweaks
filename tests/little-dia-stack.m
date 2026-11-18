#import "Patches/LittleDia/Stack.m"

DPPatch DPLittleDia;
BOOL DPIsLittleDiaWindow(NSWindow *window) { return NO; }

static int failures;

// Windows are named for their app: A and B are other apps', D is Dia's. "A1 A2 D1" reads front to back.
static NSWindow *invisibleWindow(void) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(-30000, -30000, 1, 1) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.alphaValue = 0;
    window.ignoresMouseEvents = YES;
    return window;
}

static NSString *order(NSDictionary<NSString *, NSWindow *> *windows) {
    NSMutableArray *names = [NSMutableArray array];
    for (NSWindow *window in NSApp.orderedWindows)
        for (NSString *name in windows)
            if (windows[name] == window) [names addObject:name];
    return [names componentsJoinedByString:@" "];
}

// Dia comes forward for a link with all its windows, Little Dia's first. Whatever else Dia opened in that moment stays in front of the rest.
static void restores(NSString *before, NSString *opened) {
    NSMutableDictionary<NSString *, NSWindow *> *windows = [NSMutableDictionary dictionary];
    NSMutableArray<NSDictionary *> *stack = [NSMutableArray array];
    NSMutableArray<NSString *> *dia = [NSMutableArray array], *names = [[before componentsSeparatedByString:@" "] mutableCopy];
    for (NSString *name in names) {
        windows[name] = invisibleWindow();
        BOOL mine = [name hasPrefix:@"D"];
        [stack addObject:@{@"number" : @(windows[name].windowNumber), @"pid" : @(getpid() + !mine)}];
        if (mine) [dia addObject:name];
    }
    for (NSString *name in names.reverseObjectEnumerator) [windows[name] orderFront:nil];
    NSArray<NSString *> *fresh = opened.length ? [opened componentsSeparatedByString:@" "] : @[];
    NSWindow *little = windows[@"L"] = invisibleWindow();
    for (NSString *name in fresh) windows[name] = invisibleWindow();
    for (NSString *name in dia.reverseObjectEnumerator) [windows[name] orderFront:nil];
    for (NSString *name in fresh.reverseObjectEnumerator) [windows[name] orderFront:nil];
    [little orderFront:nil];
    DPRestoreStack(little, @{@"stack" : stack, @"source" : @(getpid() + 1)});
    NSString *got = order(windows), *want = [NSString stringWithFormat:@"L %@%@", opened.length ? [opened stringByAppendingString:@" "] : @"", before];
    if (![got isEqual:want]) printf("FAIL %s, then %s opened: %s, want %s\n", before.UTF8String, opened.UTF8String, got.UTF8String, want.UTF8String), failures++;
    for (NSWindow *window in windows.allValues) [window orderOut:nil];
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        restores(@"A1 D1", @"");
        restores(@"A1 D1 D2", @"");
        restores(@"D1 A1 D2", @"");
        restores(@"A1 A2 D1", @"");
        restores(@"A1 D1 A2 D2", @"");
        restores(@"A1 A2 D1 D2 A3", @"");
        restores(@"A1 B1 D1", @"");
        restores(@"A1 A2 D1", @"D9");
        printf(failures ? "%d stack scenarios failed\n" : "all stack scenarios pass\n", failures);
        return failures != 0;
    }
}
