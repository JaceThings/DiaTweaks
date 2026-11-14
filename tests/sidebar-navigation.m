#import "Patches/SidebarNavigation/SidebarNavigation.h"
DPPatch DPSidebarNavigationControls, DPSidebarNavigation, DPSidebarHideProfile;
static DPPatch HideSidebarButton;
DPPatch *DPPatchNamed(NSString *key) {
    return [key isEqualToString:@"hideSidebarButton"] ? &HideSidebarButton : NULL;
}
@interface NavScriptTab : NSObject
@property NSString *URL;
@end
@implementation NavScriptTab @end
@interface NavScriptWindow : NSObject
@property NSString *windowId;
@property NavScriptTab *activeTab;
@end
@implementation NavScriptWindow @end
@interface NavScriptDelegate : NSObject <NSApplicationDelegate>
@property NSArray *appleScriptWindows;
@end
@implementation NavScriptDelegate @end
@interface NavFixtureButton : NSView @end
@implementation NavFixtureButton @end
static NSView *MakeView(const char *name, NSRect frame) {
    Class cls = objc_getClass(name);
    if (!cls) { cls = objc_allocateClassPair(NSView.class, name, 0); objc_registerClassPair(cls); }
    return [[cls alloc] initWithFrame:frame];
}
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,800,700) styleMask:NSWindowStyleMaskTitled backing:NSBackingStoreBuffered defer:NO];
    NSView *root = [[NSView alloc] initWithFrame:NSMakeRect(0,0,250,700)];
    [window.contentView addSubview:root];
    NSView *header = MakeView(DPDiaSidebarHeader, NSMakeRect(0,0,250,40));
    NSView *footer = MakeView(DPDiaSidebarFooter, NSMakeRect(0,670,250,30));
    NSView *toolbar = MakeView(DPDiaToolbar, NSMakeRect(250,0,550,40));
    [root addSubview:header]; [root addSubview:footer]; [window.contentView addSubview:toolbar];
    NSView *back = [NavFixtureButton new], *forward = [NavFixtureButton new], *reload = [NavFixtureButton new];
    back.accessibilityLabel = @"Go back"; forward.accessibilityLabel = @"Go forward"; reload.accessibilityLabel = @"Reload this page";
    for (NSView *button in @[back,forward,reload]) [toolbar addSubview:button];
    NSView *lights = MakeView(DPDiaTrafficLights, NSMakeRect(6,0,60,28)); [header addSubview:lights];
    NSView *wrapper = [[NSView alloc] initWithFrame:NSMakeRect(72,0,60,28)];
    NSView *profile = [[NSView alloc] initWithFrame:NSMakeRect(0,0,43,28)];
    profile.accessibilityLabel = @"Switch between profiles"; [wrapper addSubview:profile]; [header addSubview:wrapper];
    // No address row, address source files or address master are linked in this fixture.
    for (NSUInteger repeat=0; repeat<3; repeat++) {
        DPSidebarNavigation.on = DPSidebarHideProfile.on = YES;
        DPSidebarNavigationControls.on = YES; DPRefreshSidebarNavigation(header);
        NSCAssert(back.superview == header && forward.superview == header && reload.superview == header && wrapper.hidden, @"navigation works without the address patch");
        NSRect layout = back.frame; DPRefreshSidebarNavigation(header);
        NSCAssert(NSEqualRects(layout,back.frame), @"repeated layout must not drift");
        DPSidebarNavigationControls.on = NO; DPRefreshSidebarNavigation(header);
        NSCAssert(back.superview == toolbar && forward.superview == toolbar && reload.superview == toolbar && !wrapper.hidden, @"master off restores all native controls and profile");
    }
    DPSidebarNavigationControls.on = YES; DPSidebarNavigation.on = NO; DPRefreshSidebarNavigation(header);
    NSCAssert(back.superview == toolbar && wrapper.hidden, @"profile hiding works without moved navigation");
    DPSidebarHideProfile.on = NO; DPSidebarNavigation.on = YES; DPRefreshSidebarNavigation(header);
    NSCAssert(back.superview == header && !wrapper.hidden, @"moved navigation works with profile switcher visible");
    [lights removeFromSuperview]; DPRefreshSidebarNavigation(header);
    NSCAssert(back.superview == header && forward.superview == header && reload.superview == header, @"Hide Traffic Lights preserves navigation");
    NSView *download = [[NavFixtureButton alloc] initWithFrame:NSMakeRect(200,0,28,28)];
    download.accessibilityLabel = @"Downloads"; [header addSubview:download]; DPRefreshSidebarNavigation(header);
    NSCAssert(NSMinX(download.frame) >= NSMaxX(reload.frame), @"downloads keep the rightmost slot");
    [footer removeFromSuperview]; DPRefreshSidebarNavigation(header);
    NSCAssert(back.superview == toolbar && !wrapper.hidden, @"horizontal tabs suspend navigation and profile hiding");
    NSView *strip = MakeView(DPDiaTabStrip, NSMakeRect(0,0,800,62)); [window.contentView addSubview:strip];
    NSView *topLights = MakeView(DPDiaTrafficLights, NSMakeRect(14,14,60,14)); [strip addSubview:topLights];
    NSView *dock = [[NSView alloc] initWithFrame:NSMakeRect(86,5,180,32)];
    NSView *tabs = [[NSView alloc] initWithFrame:NSMakeRect(0,0,800,62)];
    [strip addSubview:tabs positioned:NSWindowBelow relativeTo:topLights]; [strip addSubview:dock];
    for (NSUInteger i=0; i<4; i++) {
        DPRefreshHorizontalNavigation(strip);
        NSCAssert(back.superview == strip && forward.superview == strip && reload.superview == strip, @"horizontal controls use the native top tab strip");
        NSCAssert(NSMinX(back.frame) == 82 && NSMaxX(reload.frame) < NSMinX(dock.frame), @"navigation fits after traffic lights and before the pinned dock");
        NSCAssert(NSMinX(dock.frame) == 178 && NSMinX(tabs.frame) == 92 && NSWidth(tabs.frame) == 708, @"dock and tabs shift equally without layout drift");
    }
    DPSidebarNavigation.on = NO; DPRefreshHorizontalNavigation(strip);
    NSCAssert(back.superview == toolbar && NSMinX(dock.frame) == 86 && NSMinX(tabs.frame) == 0 && NSWidth(tabs.frame) == 800, @"horizontal option off restores native frames and buttons");
    DPSidebarNavigation.on = YES; DPRefreshHorizontalNavigation(strip);
    topLights.hidden = YES; DPRefreshHorizontalNavigation(strip);
    NSCAssert(NSMinX(back.frame) == 14, @"hidden traffic lights leave navigation visible");
    topLights.hidden = NO;
    strip.frameSize = NSMakeSize(250,62); DPRefreshHorizontalNavigation(strip);
    NSCAssert(back.superview == strip && forward.superview == toolbar && reload.superview == toolbar, @"narrow strips retain Back and return lower-priority buttons to the toolbar");
    strip.frameSize = NSMakeSize(800,62); DPRefreshHorizontalNavigation(strip);
    [root addSubview:footer]; DPRefreshHorizontalNavigation(strip);
    NSCAssert(back.superview == toolbar && NSMinX(dock.frame) == 86, @"returning to sidebar tabs restores the top strip before relocating navigation");
    DPRefreshSidebarNavigation(header);
    NSCAssert(back.superview == header, @"returning to sidebar tabs restores navigation");
    DPRestoreSidebarNavigation(DPNavigationState(header,NO));
    NSCAssert(back.superview == toolbar && !DPNavigationSlotFor(back), @"shutdown cleanup releases ownership");
    NSView *otherToolbar = MakeView(DPDiaToolbar, NSMakeRect(250,40,550,40));
    NSView *field = MakeView(DPDiaAddressField, NSMakeRect(0,0,200,30));
    NSTextView *text = [[NSTextView alloc] initWithFrame:field.bounds]; text.string = @"www.example.com/page";
    [field addSubview:text]; [otherToolbar addSubview:field]; [window.contentView addSubview:otherToolbar];
    NSView *otherBack = [NavFixtureButton new]; otherBack.accessibilityLabel = @"Go back"; [otherToolbar addSubview:otherBack];
    NavScriptTab *tab = [NavScriptTab new]; tab.URL = @"https://www.example.com/page";
    NavScriptWindow *scripted = [NavScriptWindow new]; scripted.windowId = @"fixture"; scripted.activeTab = tab; window.identifier = @"fixture";
    NavScriptDelegate *delegate = [NavScriptDelegate new]; delegate.appleScriptWindows = @[scripted]; NSApp.delegate = delegate;
    DPRefreshSidebarNavigation(header);
    NSCAssert(otherBack.superview == header && back.superview == toolbar, @"navigation must follow the active toolbar when several are visible");
    DPRestoreSidebarNavigation(DPNavigationState(header,NO));
    NSView *toggle = [NavFixtureButton new];
    toggle.accessibilityLabel = @"Toggle sidebar";
    [otherToolbar addSubview:toggle];
    [header addSubview:lights];
    DPSidebarHideProfile.on = YES;
    DPRefreshSidebarNavigation(header);
    NSCAssert(toggle.superview == header && NSMinX(toggle.frame) == NSMaxX(lights.frame) + 4 &&
        NSMaxX(toggle.frame) <= NSMinX(otherBack.frame), @"sidebar toggle leads navigation beside traffic lights");
    NSView *floating = MakeView(DPDiaFloatingSidebar, root.frame);
    [window.contentView addSubview:floating];
    [root removeFromSuperview]; [floating addSubview:root];
    for (NSUInteger cycle = 0; cycle < 3; cycle++) {
        root.hidden = floating.hidden = YES;
        wrapper.hidden = NO; // Dia can relayout the profile indicator while moving the sidebar.
        DPRefreshSidebarNavigation(header);
        NSCAssert(toggle.superview == header && wrapper.hidden && NSMinX(toggle.frame) == NSMaxX(lights.frame) + 4,
            @"the floating sidebar keeps its controls in place while hidden");
        NSCAssert(!DPHorizontalNavigationAvailable(strip), @"an auto-hidden sidebar still uses vertical tabs");
        root.hidden = NO;
        DPRefreshSidebarNavigation(header);
        floating.hidden = NO;
        NSCAssert(toggle.superview == header && !toggle.hiddenOrHasHiddenAncestor && wrapper.hidden,
            @"the first visible sidebar frame already shows the toggle and hides the profile");
    }
    lights.hidden = YES;
    DPRefreshSidebarNavigation(header);
    NSCAssert(NSMinX(toggle.frame) == 6, @"hidden leading controls move the sidebar toggle left");
    HideSidebarButton.on = YES;
    DPRefreshSidebarNavigation(header);
    NSCAssert(toggle.superview == otherToolbar, @"Hide Sidebar Button returns the toggle to its native owner");
    HideSidebarButton.on = NO;
    [footer removeFromSuperview]; DPRefreshSidebarNavigation(header);
    DPRefreshHorizontalNavigation(strip);
    NSCAssert(toggle.superview == strip && NSMinX(toggle.frame) == 82 && NSMinX(otherBack.frame) == 110,
        @"horizontal navigation starts with the sidebar toggle");
    topLights.hidden = YES; DPRefreshHorizontalNavigation(strip);
    NSCAssert(NSMinX(toggle.frame) == 14 && NSMinX(otherBack.frame) == 42,
        @"the horizontal toggle moves left when traffic lights are hidden");
    DPSidebarNavigation.on = NO; DPRefreshHorizontalNavigation(strip);
    NSCAssert(toggle.superview == otherToolbar && !DPNavigationSlotFor(toggle), @"turning navigation off restores the native toggle");
    puts("PASS: standalone navigation, master/child toggle combinations, restoration, no drift, traffic lights, downloads, horizontal placement/restoration, narrow widths, and shutdown cleanup");
} }
