#import "Patches/SwipeNewProfile/SwipeNewProfile.h"

static NSMenuItem *DPNewProfileItem(NSMenu *menu) {
    for (NSMenuItem *item in menu.itemArray) {
        if ([item.title isEqualToString:@"New Profile…"] && item.action) return item;
        NSMenuItem *found = item.submenu ? DPNewProfileItem(item.submenu) : nil;
        if (found) return found;
    }
    return nil;
}

BOOL DPHasNewProfileItem(void) { return DPNewProfileItem(NSApp.mainMenu) != nil; }

// Dia opens New Profile for the key window, so make the swiped one key first.
void DPOpenNewProfile(NSWindow *window) {
    NSMenuItem *item = DPNewProfileItem(NSApp.mainMenu);
    if (!item || !window.isVisible) return;
    if (!window.isKeyWindow) [window makeKeyAndOrderFront:nil];
    [item.menu performActionForItemAtIndex:[item.menu indexOfItem:item]];
}

// A trackpad scroll event with no movement that cancels a swipe. It has no window, so it only reaches Dia
// through its swipe loop, which reads the queue: Dia then settles back on the last profile.
NSEvent *DPCancelDiaSwipe(void) {
    CGEventRef scroll = CGEventCreateScrollWheelEvent2(NULL, kCGScrollEventUnitPixel, 2, 0, 0, 0);
    if (!scroll) return nil;
    NSPoint mouse = NSEvent.mouseLocation;
    CGEventSetLocation(scroll, CGPointMake(mouse.x, NSMaxY(NSScreen.screens.firstObject.frame) - mouse.y));
    CGEventSetIntegerValueField(scroll, kCGScrollWheelEventIsContinuous, 1);
    CGEventSetIntegerValueField(scroll, kCGScrollWheelEventScrollPhase, kCGScrollPhaseCancelled);
    NSEvent *event = [NSEvent eventWithCGEvent:scroll];
    CFRelease(scroll);
    if (event) [NSApp postEvent:event atStart:YES];
    return event;
}
