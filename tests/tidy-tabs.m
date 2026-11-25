#import "Patches/TidyTabs/TidyTabs.h"
#import "Patches/CommandBar/Tabs.h"
#import "StdPatch/Hook.m"
#import "StdPatch/Views.m"

static int hookCalls;
static void DPCountedHookClass(Class cls, SEL sel, IMP replacement) {
    hookCalls++;
    DPHookClass(cls, sel, replacement);
}
#define DPHookClass DPCountedHookClass

DPPatch DPTidyTabs;
static BOOL tidyBusy;

@implementation DPTidyHover
+ (DPTidyHover *)forList:(NSView *)list { return nil; }
+ (DPTidyHover *)attachToList:(NSView *)list {
    DPTidyHover *hover = [DPTidyHover new];
    hover.progress = 1;
    return hover;
}
- (void)detach {}
- (void)track {}
@end
@implementation DPTidyBrush
- (void)showBusy {}
@end
@implementation DPTidyRowView
@end
DPTidyRowView *DPTidyRowIn(NSView *list, BOOL create) { return nil; }
NSHashTable<DPTidyBrush *> *DPTidyBrushes(void) { return [NSHashTable weakObjectsHashTable]; }
BOOL DPTidyIsBusy(void) { return tidyBusy; }
void DPTidyWave(CALayer *host, CALayer *line, CGColorRef color, BOOL busy) {}

#import "Patches/TidyTabs/Layout.m"
#import "Patches/TidyTabs/Separator.m"

@interface DPFakeTab : NSObject
@property NSString *URL, *title;
@property (getter=isPinned) BOOL pinned;
@end
@implementation DPFakeTab
@end

@interface DPFakeScriptWindow : NSObject
@property NSString *windowId;
@property NSArray *appleScriptTabs;
@end
@implementation DPFakeScriptWindow
@end

@interface DPFakeDelegate : NSObject <NSApplicationDelegate>
@property NSArray *appleScriptWindows;
@end
@implementation DPFakeDelegate
@end

static int failures;

static void expectEqual(id got, id want, NSString *what) {
    if ([got isEqual:want] || got == want) return;
    failures++;
    printf("FAIL %s: got %s, want %s\n", what.UTF8String, [[got description] UTF8String], [[want description] UTF8String]);
}

static DPFakeTab *tab(NSString *url, NSString *title, BOOL pinned) {
    DPFakeTab *tab = [DPFakeTab new];
    tab.URL = url;
    tab.title = title;
    tab.pinned = pinned;
    return tab;
}

static DPFakeScriptWindow *scripted(NSString *windowID, NSArray *tabs) {
    DPFakeScriptWindow *window = [DPFakeScriptWindow new];
    window.windowId = windowID;
    window.appleScriptTabs = tabs;
    return window;
}

static NSWindow *window(NSString *identifier) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 400, 300)
        styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    window.identifier = identifier;
    window.releasedWhenClosed = NO;
    return window;
}


static char DPFakeDiaKey, DPFakeScrollKey;
static NSInteger frameWrites, lineWrites, lookups;

@interface DPCountingScroll : NSScrollView
@end
@implementation DPCountingScroll
- (void)setFrame:(NSRect)frame {
    if (!NSEqualRects(frame, [objc_getAssociatedObject(self, &DPFakeDiaKey) rectValue])) frameWrites++;
    [super setFrame:frame];
}
@end

@interface DPCountingLayer : CALayer
@end
@implementation DPCountingLayer
- (void)setFrame:(CGRect)frame {
    if (!NSEqualRects(frame, [objc_getAssociatedObject(self, &DPFakeDiaKey) rectValue])) lineWrites++;
    [super setFrame:frame];
}
@end

@interface DPFakeLayout : NSCollectionViewLayout
@property NSArray<NSArray<NSValue *> *> *frames;
@property NSSet<NSString *> *hidden;
@end
@implementation DPFakeLayout
- (NSCollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)path {
    NSCollectionViewLayoutAttributes *attrs = [NSCollectionViewLayoutAttributes layoutAttributesForItemWithIndexPath:path];
    attrs.frame = self.frames[(NSUInteger)path.section][(NSUInteger)path.item].rectValue;
    attrs.hidden = [self.hidden containsObject:[NSString stringWithFormat:@"%ld.%ld", (long)path.section, (long)path.item]];
    return attrs;
}
@end

@interface DPFakeCollection : NSCollectionView
@property (strong) DPFakeLayout *fakeLayout;
@property NSArray<NSArray<NSNumber *> *> *kinds;
@end
@implementation DPFakeCollection
- (NSCollectionViewLayout *)collectionViewLayout { return self.fakeLayout; }
- (NSInteger)numberOfSections { return (NSInteger)self.kinds.count; }
- (NSInteger)numberOfItemsInSection:(NSInteger)section { return (NSInteger)self.kinds[(NSUInteger)section].count; }
- (NSCollectionViewItem *)itemAtIndexPath:(NSIndexPath *)path {
    lookups++;
    NSInteger kind = self.kinds[(NSUInteger)path.section][(NSUInteger)path.item].integerValue;
    if (!kind) return nil;
    NSCollectionViewItem *item = [NSCollectionViewItem new];
    item.view = [kind == 1 ? objc_getClass("_TtC5TabUI7TabView") : objc_getClass(DPDiaTabGroupCell) new];
    return item;
}
@end

static void restoreScroll(NSView *self, SEL _cmd) {
    NSScrollView *scroll = objc_getAssociatedObject(self, &DPFakeScrollKey);
    NSValue *dia = objc_getAssociatedObject(scroll, &DPFakeDiaKey);
    if (dia) [scroll setFrame:dia.rectValue];
}

static void restoreLine(NSView *self, SEL _cmd) {
    for (CALayer *layer in self.layer.sublayers) {
        NSValue *dia = objc_getAssociatedObject(layer, &DPFakeDiaKey);
        if (dia) layer.frame = dia.rectValue;
    }
}

static Class makeClass(const char *name, Class parent, SEL sel, IMP imp) {
    Class cls = objc_allocateClassPair(parent, name, 0);
    if (imp) class_addMethod(cls, sel, imp, "v@:");
    objc_registerClassPair(cls);
    return cls;
}

int main(void) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        DPFakeDelegate *delegate = [DPFakeDelegate new];
        NSApp.delegate = delegate;

        NSWindow *older = window(@"A"), *newer = window(@"B"), *stranger = window(@"C");
        delegate.appleScriptWindows = @[
            scripted(@"A", @[ tab(@"https://a.example/1", @"A one", NO), tab(@"https://shared.example/", @"Shared", NO), tab(@"https://a.example/2", @"A two", NO) ]),
            scripted(@"B", @[ tab(@"https://shared.example/", @"Shared", YES), tab(@"https://b.example/1", @"B one", NO), tab(@"https://b.example/2", nil, NO), tab(@"", @"No address", NO) ]),
        ];

        expectEqual(DPTidyLooseTabs(older), (@{ @"https://a.example/1": @"A one", @"https://shared.example/": @"Shared", @"https://a.example/2": @"A two" }),
            @"the first window lists its own tabs");
        expectEqual(DPTidyLooseTabs(newer), (@{ @"https://b.example/1": @"B one", @"https://b.example/2": @"https://b.example/2" }),
            @"the second window lists its own tabs, not the first window's, and keeps a favorite out");
        expectEqual(DPTidyLooseTabs(stranger), @{}, @"a window Dia doesn't script has no loose tabs");
        expectEqual(DPTidyLooseTabs(nil), @{}, @"no window has no loose tabs");

        delegate.appleScriptWindows = @[ scripted(@"B", (id)@"not a list") ];
        expectEqual(DPTidyLooseTabs(newer), @{}, @"a window without a tab list has no loose tabs");
        delegate.appleScriptWindows = @[];
        expectEqual(DPTidyLooseTabs(newer), @{}, @"no scripted windows means no loose tabs");

        NSString *emojiPath = [NSString stringWithFormat:@"https://example.com/%@/%@", [@"" stringByPaddingToLength:57 withString:@"a" startingAtIndex:0], @"\U0001F525tail"];
        NSString *trimmed = DPTidyAddress(emojiPath, @"example.com");
        unichar last = trimmed.length ? [trimmed characterAtIndex:trimmed.length - 1] : 0;
        expectEqual(@(trimmed.length <= 70 && [trimmed UTF8String] != NULL && (last < 0xD800 || last > 0xDBFF)), @YES,
            @"address truncation does not split a UTF-16 surrogate pair");
    }
    checkTidyLayout();
    if (!failures) printf("all Tidy Tabs checks passed\n");
    return failures ? 1 : 0;
}
