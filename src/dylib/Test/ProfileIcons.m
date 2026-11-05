#import "Test/Test.h"
#import "Patches/ProfileEmoji/ProfileIcons.h"

static NSUserDefaults *DPSavedIconDefaults;
static NSString *DPProfileTestDomain, *DPProfileTestCase;
static NSDictionary<NSString *, NSArray<NSString *> *> *DPProfileSelections;
static NSMapTable<NSView *, id> *DPSavedIconAppearances;

static NSDictionary<NSString *, NSArray<NSView *> *> *DPProfileTestViews(void) {
    NSMutableDictionary *profiles = [NSMutableDictionary dictionary];
    for (NSString *name in @[ @DPDiaSpaceSwitcherItem, @DPDiaPageIndicatorDot ]) {
        NSString *field = [name isEqual:@DPDiaSpaceSwitcherItem] ? @"itemViews" : @"dotViews";
        for (NSView *view in DPFindViews(name.UTF8String)) {
            if (view.hiddenOrHasHiddenAncestor) continue;
            NSDictionary *views = DPSwiftValue(view.superview, field);
            for (id key in views) if (views[key] == view) {
                NSString *spaceID = [key description];
                if (!profiles[spaceID]) profiles[spaceID] = [NSMutableArray array];
                [profiles[spaceID] addObject:view];
            }
        }
    }
    return profiles;
}

NSArray<NSArray<NSString *> *> *DPProfileIconScenarios(NSString *savedBits) {
    if (DPProfileEmoji.unavailable) return @[];
    NSUInteger index = 0;
    while (index < DPPatchCount && DPPatches[index] != &DPProfileEmoji) index++;
    NSMutableArray *scenarios = [NSMutableArray array];
    for (NSArray *entry in @[
        @[@"Default dots", @"dots"], @[@"Legacy emoji", @"emoji"], @[@"SF Symbols", @"symbols"],
        @[@"Unavailable symbol with emoji", @"fallback"], @[@"Unavailable symbol without emoji", @"unavailable"],
        @[@"Mixed icons (light)", @"light"], @[@"Mixed icons (dark)", @"dark"], @[@"Icons off", @"off"],
        @[@"Icons on again", @"symbols"], @[@"Reset", @"reset"],
    ]) {
        NSMutableString *bits = [savedBits mutableCopy];
        [bits replaceCharactersInRange:NSMakeRange(index, 1) withString:[entry[1] isEqual:@"off"] ? @"0" : @"1"];
        [scenarios addObject:@[[@"Profile icons: " stringByAppendingString:entry[0]], bits, entry[1]]];
    }
    return scenarios;
}

void DPApplyProfileIconTestCase(NSString *name) {
    for (NSView *view in DPSavedIconAppearances) {
        id appearance = [DPSavedIconAppearances objectForKey:view];
        view.appearance = appearance == NSNull.null ? nil : appearance;
    }
    DPSavedIconAppearances = nil;
    DPProfileTestCase = name;
    if (!name) {
        if (!DPSavedIconDefaults) return;
        [DPEmojiDefaults removePersistentDomainForName:DPProfileTestDomain];
        DPEmojiDefaults = DPSavedIconDefaults;
        DPSavedIconDefaults = nil;
        DPProfileTestDomain = nil;
        DPProfileSelections = nil;
        DPRefreshProfileIcons();
        return;
    }
    if (!DPSavedIconDefaults) {
        DPSavedIconDefaults = DPEmojiDefaults;
        DPProfileTestDomain = [@"com.diatweaks.profile-icons-test." stringByAppendingString:NSUUID.UUID.UUIDString];
        DPEmojiDefaults = [[NSUserDefaults alloc] initWithSuiteName:DPProfileTestDomain];
    }
    [DPEmojiDefaults removeObjectForKey:@"profileEmojis"];
    [DPEmojiDefaults removeObjectForKey:@"profileSymbols"];
    NSDictionary *views = DPProfileTestViews();
    NSMutableDictionary *selections = [NSMutableDictionary dictionary];
    NSArray *spaceIDs = [views.allKeys sortedArrayUsingSelector:@selector(compare:)];
    BOOL mixed = [name isEqual:@"light"] || [name isEqual:@"dark"];
    for (NSUInteger i = 0; i < spaceIDs.count; i++) {
        NSString *spaceID = spaceIDs[i];
        NSArray *selection = @[@"", @"", @"dot", @""];
        if ([name isEqual:@"emoji"]) selection = @[@"🧑🏽‍💻", @"", @"emoji", @"🧑🏽‍💻"];
        if ([name isEqual:@"symbols"] || [name isEqual:@"off"]) selection = @[@"🌿", @"briefcase", @"symbol", @"briefcase.fill"];
        if ([name isEqual:@"fallback"]) selection = @[@"🌿", @"not.a.real.symbol", @"emoji", @"🌿"];
        if ([name isEqual:@"unavailable"]) selection = @[@"", @"not.a.real.symbol", @"dot", @""];
        if (mixed) selection = (@[ @[@"🌿", @"briefcase", @"symbol", @"briefcase.fill"], @[@"🌿", @"", @"emoji", @"🌿"], @[@"", @"", @"dot", @""] ])[i % 3];
        selections[spaceID] = selection;
        if ([name isEqual:@"emoji"]) continue;
        if ([name isEqual:@"reset"]) DPStoreProfileIcon(spaceID, @"🌿", @"briefcase");
        DPStoreProfileIcon(spaceID, selection[0], selection[1]);
    }
    if ([name isEqual:@"emoji"]) {
        NSMutableDictionary *legacy = [NSMutableDictionary dictionary];
        for (NSString *spaceID in spaceIDs) legacy[spaceID] = @"🧑🏽‍💻";
        [DPEmojiDefaults setObject:legacy forKey:@"profileEmojis"];
    }
    DPProfileSelections = selections;
    if (mixed) {
        DPSavedIconAppearances = [NSMapTable strongToStrongObjectsMapTable];
        NSAppearance *appearance = [NSAppearance appearanceNamed:[name isEqual:@"dark"] ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua];
        for (NSArray<NSView *> *hosts in views.allValues) for (NSView *host in hosts) {
            NSView *parent = host.superview;
            if ([DPSavedIconAppearances objectForKey:parent]) continue;
            [DPSavedIconAppearances setObject:parent.appearance ?: NSNull.null forKey:parent];
            parent.appearance = appearance;
        }
    }
    DPRefreshProfileIcons();
}

NSString *DPVerifyProfileIconTestCase(void) {
    if (!DPProfileTestCase) return nil;
    NSDictionary<NSString *, NSArray<NSView *> *> *profiles = DPProfileTestViews();
    if (!profiles.count) return @"No profile switcher views found for the current layout";
    [DPEmojiDefaults synchronize];
    NSUserDefaults *reloaded = [[NSUserDefaults alloc] initWithSuiteName:DPProfileTestDomain];
    for (NSString *spaceID in profiles) {
        NSArray *selection = DPProfileSelections[spaceID];
        if (!selection) return @"A profile appeared after the test case was prepared";
        NSString *emoji = [reloaded dictionaryForKey:@"profileEmojis"][spaceID] ?: @"";
        NSString *symbol = [reloaded dictionaryForKey:@"profileSymbols"][spaceID] ?: @"";
        if (![emoji isEqual:selection[0]] || ![symbol isEqual:selection[1]]) return @"Profile icon persistence does not match the test selection";
        for (NSView *host in profiles[spaceID]) {
            NSView *icon = DPFindView(host, ^BOOL(NSView *view) { return [view.identifier isEqual:@"diatweaks.profileIcon"]; });
            NSString *kind = [DPProfileTestCase isEqual:@"off"] ? @"dot" : selection[2];
            if ([kind isEqual:@"dot"]) {
                if (icon) return @"Expected a default dot, but a custom icon is still present";
            } else if ([kind isEqual:@"emoji"]) {
                if (![icon isKindOfClass:NSTextField.class] || ![[(NSTextField *)icon stringValue] isEqual:selection[3]]) return @"Emoji or unavailable-symbol fallback is incorrect";
            } else {
                if (![icon isKindOfClass:NSImageView.class] || ![((NSImageView *)icon).image.accessibilityDescription isEqual:selection[3]]) return @"SF Symbol or bundled icon does not match the selection";
            }
            if (DPIsKind(host, DPDiaSpaceSwitcherItem) && ![kind isEqual:@"dot"] && fabs(NSWidth(host.frame) - ([kind isEqual:@"symbol"] ? 32 : 26)) > 0.01) return @"Profile switcher cell width is incorrect";
            if (icon && ([DPProfileTestCase isEqual:@"light"] || [DPProfileTestCase isEqual:@"dark"])) {
                NSString *appearance = [icon.effectiveAppearance bestMatchFromAppearancesWithNames:@[ NSAppearanceNameAqua, NSAppearanceNameDarkAqua ]];
                NSString *expected = [DPProfileTestCase isEqual:@"dark"] ? NSAppearanceNameDarkAqua : NSAppearanceNameAqua;
                if (![appearance isEqual:expected]) return @"Profile icon did not inherit the test appearance";
            }
        }
    }
    return [DPProfileTestCase isEqual:@"symbols"] ? DPVerifyProfileIconPicker() : nil;
}
