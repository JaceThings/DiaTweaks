#import "Patches/Easels/Portable.h"
#import "Patches/Easels/Canvas.h"
#import <objc/runtime.h>
DPPatch DPEasels={.on=YES};
static NSString *root; static BOOL shown;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
static void DPShow(id self,SEL cmd,NSRect rect,NSView *view,NSRectEdge edge) { shown=YES; }
static void waitFor(BOOL (^done)(void)) { NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:10]; while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]]; NSCAssert(done(),@"sharing export completes"); }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    Method show=class_getInstanceMethod(NSSharingServicePicker.class,@selector(showRelativeToRect:ofView:preferredEdge:)); IMP original=method_setImplementation(show,(IMP)DPShow);
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(400,500)]; [document rename:@"Copy / Test"];
    DPEaselEditorSurface *surface=(id)DPEaselEditor(document);
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,600,600) styleMask:0 backing:NSBackingStoreBuffered defer:NO]; window.releasedWhenClosed=NO; window.contentView=surface; [surface layoutSubtreeIfNeeded];
    NSViewController *export=[NSClassFromString(@"DPEaselExportController") new]; [export setValue:surface forKey:@"surface"]; NSView *form=export.view;
    NSMutableArray<NSButton *> *options=NSMutableArray.new; NSButton *share=nil;
    for(NSView *view in form.subviews) if([view isKindOfClass:NSButton.class]) {
        NSButton *button=(id)view; if([@[@"Editable copy",@"Preview only"] containsObject:button.title]) {  [options addObject:button]; }
        if([button.title isEqual:@"Share Copy…"]) share=button;
    }
    NSCAssert(options.count==2 && fabs(NSMinY(options[0].frame)-NSMinY(options[1].frame))>60,@"share choices are vertically separated native radio rows");
    for(NSNumber *editable in @[@YES,@NO]) {
        [options[editable.boolValue ? 0 : 1] performClick:nil];
        NSCAssert((options[0].state==NSControlStateValueOn)==editable.boolValue && (options[1].state==NSControlStateValueOn)!=editable.boolValue,@"radio choices are mutually exclusive");
        shown=NO; [share performClick:nil]; waitFor(^BOOL{ return shown; });
        id session=surface.sharingSession; NSURL *file=[session valueForKey:@"file"],*directory=[session valueForKey:@"directory"];
        NSData *data=[NSData dataWithContentsOfURL:file]; NSCAssert(data.length && ![file.lastPathComponent containsString:@"/"],@"share uses a named self-contained temporary file");
        NSCAssert((DPEaselReadPortable(data,nil)!=nil)==editable.boolValue,@"share mode preserves editable versus preview-only payloads");
        NSSharingServicePicker *picker=[session valueForKey:@"picker"];
        [picker.delegate sharingServicePicker:picker didChooseSharingService:nil];
        NSCAssert(!surface.sharingSession && surface.exportButton.enabled && ![NSFileManager.defaultManager fileExistsAtPath:directory.path],@"cancelling native picker releases session and temporary export");
    }
    method_setImplementation(show,original); [surface removeFromSuperview]; [window close]; [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: editable/preview sharing preparation, native picker handoff and cancellation cleanup without transmitting files");
} }
