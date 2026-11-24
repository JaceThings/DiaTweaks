#import "Library.h"
#import <Quartz/Quartz.h>
#import <objc/message.h>
#import <dlfcn.h>
@interface DPLibraryPreviewSource : NSObject <QLPreviewPanelDataSource>
@property NSArray<NSURL *> *urls;
@end
@implementation DPLibraryPreviewSource
- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel { return self.urls.count; }
- (id<QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
    return index >= 0 && index < (NSInteger)self.urls.count ? self.urls[index] : nil;
}
@end
static id DPLibraryPreviewPanel(void) {
    static dispatch_once_t once;
    dispatch_once(&once,^{ dlopen("/System/Library/Frameworks/Quartz.framework/Frameworks/QuickLookUI.framework/QuickLookUI",RTLD_LAZY); });
    Class cls = NSClassFromString(@"QLPreviewPanel");
    return cls ? ((id (*)(id,SEL))objc_msgSend)(cls,@selector(sharedPreviewPanel)) : nil;
}
void DPLibraryTogglePreview(DPLibraryController *controller,NSResponder *responder) {
    NSArray *urls = controller.selectedFileURLs; if (!urls.count) return;
    QLPreviewPanel *panel = DPLibraryPreviewPanel(); if (!panel) return;
    if (panel.visible && panel.currentController == responder) { [panel orderOut:nil]; return; }
    DPLibraryPreviewSource *source = [DPLibraryPreviewSource new]; source.urls = urls; controller.previewSource = source;
    [controller.window makeFirstResponder:responder];
    [panel makeKeyAndOrderFront:nil]; [panel updateController];
    if (panel.currentController == responder) [panel reloadData];
    else [panel orderOut:nil];
}
void DPLibraryClosePreview(DPLibraryController *controller) {
    if (!controller.previewSource) return;
    QLPreviewPanel *panel = DPLibraryPreviewPanel();
    if (panel.currentController == controller.table || panel.currentController == controller.collection) [panel orderOut:nil];
    controller.previewSource = nil;
}
@implementation DPLibraryController (QuickLook)
- (void)quickLook:(id)sender {
    NSResponder *responder = [self.section isEqual:@"Media"] ? self.collection : self.table;
    DPLibraryTogglePreview(self,responder);
}
@end
