#import "DevMode.h"
#import <objc/message.h>

void DPCaptureViewport(id page, void (^done)(NSImage *image)) {
    if (![page respondsToSelector:@selector(captureViewport:)]) return done(nil);
    ((void (*)(id, SEL, void (^)(id)))objc_msgSend)(page, @selector(captureViewport:), ^(id image) {
        dispatch_async(dispatch_get_main_queue(), ^{ done([image isKindOfClass:NSImage.class] ? image : nil); });
    });
}

static void DPCopyImage(NSImage *image) {
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithCGImage:[image CGImageForProposedRect:NULL context:nil hints:nil]];
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setData:[rep representationUsingType:NSBitmapImageFileTypePNG properties:@{}] forType:NSPasteboardTypePNG];
    [pasteboard setData:image.TIFFRepresentation forType:NSPasteboardTypeTIFF];
}

void DPCapturePortrait(id page) {
    NSView *pane = DPPaneOf(page);
    NSString *title = [page respondsToSelector:@selector(title)] ? [page performSelector:@selector(title)] : nil;
    DPCaptureViewport(page, ^(NSImage *shot) {
        NSImage *image = shot ? DPPortraitImage(shot, pane.window, 0, DPPortraitAspect) : nil;
        if (!image) return NSBeep();
        DPCopyImage(image);
        if (pane) DPShowCaptureToast(pane, image, title.length ? title : DPHostOf(page));
    });
}
