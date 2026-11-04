#import "LittleDia.h"
#import <Carbon/Carbon.h>

// Where the window opens: centred on the screen with the pointer, at the size in Settings or as near as fits.
static NSRect DPLittleDiaFrame(void) {
    NSScreen *screen = NSScreen.mainScreen;
    for (NSScreen *each in NSScreen.screens)
        if (NSMouseInRect(NSEvent.mouseLocation, each.frame, NO)) screen = each;
    NSRect visible = screen.visibleFrame;
    NSSize wanted = DPLittleDiaSize();
    NSSize size = NSMakeSize(round(MIN(wanted.width, NSWidth(visible) * 0.95)), round(MIN(wanted.height, NSHeight(visible) * 0.95)));
    return NSMakeRect(round(NSMidX(visible) - size.width / 2), round(NSMidY(visible) - size.height / 2), size.width, size.height);
}

// Links clicked in Dia, and any sent while Option is held, open as Dia would. So does anything that isn't a web page.
static BOOL DPOpenInLittleDia(NSAppleEventDescriptor *event) {
    if (event.eventClass != kInternetEventClass || event.eventID != kAEGetURL) return NO;
    NSString *string = [event paramDescriptorForKeyword:keyDirectObject].stringValue;
    NSURL *url = string ? [NSURL URLWithString:string] : nil;
    NSString *scheme = url.scheme.lowercaseString;
    if (![scheme isEqual:@"http"] && ![scheme isEqual:@"https"]) return NO;
    if ([event attributeDescriptorForKeyword:keySenderPIDAttr].int32Value == getpid()) return NO;
    if (NSEvent.modifierFlags & NSEventModifierFlagOption) return NO;

    NSRect frame = DPLittleDiaFrame();
    CGFloat top = NSMaxY(NSScreen.screens.firstObject.frame) - NSMaxY(frame);  // Chromium measures down from the top.
    NSDictionary *request = @{
        @"action" : @"open",
        @"url" : url.absoluteString,
        @"left" : @(NSMinX(frame)),
        @"top" : @(top),
        @"width" : @(NSWidth(frame)),
        @"height" : @(NSHeight(frame)),
    };
    DPNoteStackForLink();
    return DPSendToLittleDia(request);
}

// If no window comes, the link opens as Dia would have opened it.
static void DPOpenURLEvents_handle(id self, SEL _cmd, NSAppleEventDescriptor *event, NSAppleEventDescriptor *reply) {
    if (!DPLittleDia.on || !DPOpenInLittleDia(event)) return DPCallOriginal(DPOpenURLEvents_handle, self, event, reply);
    DPExpectLittleDiaWindow(^{ DPCallOriginal(DPOpenURLEvents_handle, self, event, [NSAppleEventDescriptor nullDescriptor]); });
}

void DPInstallLittleDiaRoute(void) {
    DPHook(DPDiaOpenURLEvents, @selector(handleEvent:withReplyEvent:), (IMP)DPOpenURLEvents_handle);
}
