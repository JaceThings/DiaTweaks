#import "Patches/Easels/HostInternal.h"
#import <objc/runtime.h>
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root,*current;
static IMP commandHook; static SEL nativeCommand;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.controlAccentColor; }
@interface FixtureAddressSession : NSObject <NSApplicationDelegate>
@end
@implementation FixtureAddressSession
- (NSArray *)appleScriptWindows { return @[self]; }
- (NSString *)windowId { return @"easel-address-fixture"; }
- (id)activeTab { return self; }
- (NSString *)URL { return current; }
@end
void DPHook(const char *name,SEL selector,IMP replacement) {}
void DPHookClass(Class cls,SEL selector,IMP replacement) { if(selector==@selector(doCommandBySelector:)) commandHook=replacement; }
static void originalCommand(id object,SEL selector,SEL command) { nativeCommand=command; }
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return (IMP)originalCommand; }
id DPGet(id object,const void *key) { return objc_getAssociatedObject(object,key); }
void DPSet(id object,const void *key,id value) { objc_setAssociatedObject(object,key,value,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@interface FixtureNativeAddress : NSView @end
@implementation FixtureNativeAddress @end
BOOL DPIsKind(id object,const char *name) { return !strcmp(name,DPDiaAddressField) && [object isKindOfClass:FixtureNativeAddress.class]; }
NSView *DPFindView(NSView *view,BOOL (^match)(NSView *)) { if(match(view)) return view; for(NSView *child in view.subviews) { NSView *found=DPFindView(child,match); if(found) return found; } return nil; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:[@"Address Board " stringByAppendingString:NSUUID.UUID.UUIDString]];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(900,1400)]; [document rename:@"A friendly board"];
    [DPEaselStore.shared save:document completion:nil]; [DPEaselStore.shared flush];
    current=[DPEaselStore.shared pageURL:document.identifier].absoluteString;
    FixtureAddressSession *session = FixtureAddressSession.new;
    NSApp.delegate = session;
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,300,200) styleMask:NSWindowStyleMaskBorderless backing:NSBackingStoreBuffered defer:NO];
    window.identifier = @"easel-address-fixture";
    FixtureNativeAddress *bar=FixtureNativeAddress.new; window.contentView = bar; NSTextView *field=NSTextView.new; [bar addSubview:field]; field.string=current;
    DPEaselInstallNativeAddress(); DPEaselUpdateAddressField(field);
    NSCAssert([field.string isEqual:@"A friendly board"],@"native address presentation exposes the board name instead of its internal file path");
    field.string=current.stringByRemovingPercentEncoding; DPEaselUpdateAddressField(field);
    NSCAssert([field.string isEqual:@"A friendly board"],@"the native top bar's decoded file presentation also uses the name");
    [field.textStorage setAttributedString:[[NSAttributedString alloc] initWithString:current]];
    [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.02]];
    NSCAssert([field.string isEqual:@"A friendly board"],@"native attributed-storage rebuild after a layout switch restores the friendly name");
    ((void (*)(id,SEL,SEL))commandHook)(field,@selector(doCommandBySelector:),@selector(insertNewline:));
    NSCAssert(nativeCommand==@selector(cancelOperation:),@"Return on an unchanged title dismisses editing rather than searching for the alias");
    [document rename:@"Renamed board"]; DPEaselRefreshAddressFields();
    NSCAssert([field.string isEqual:@"Renamed board"],@"title updates propagate to existing native address presentation");
    field.string=@"https://example.com/new"; DPEaselUpdateAddressField(field); nativeCommand=NULL;
    ((void (*)(id,SEL,SEL))commandHook)(field,@selector(doCommandBySelector:),@selector(insertNewline:));
    NSCAssert([field.string isEqual:@"https://example.com/new"] && nativeCommand==@selector(insertNewline:),@"a replacement query or URL keeps normal native submission behavior");
    field.string=current; DPEaselUpdateAddressField(field); DPEasels.on=NO; DPEaselRefreshAddressFields();
    NSCAssert([field.string isEqual:current],@"patch disable restores the native value without changing the real tab URL");
    DPEasels.on=YES; NSTextView *body=NSTextView.new; body.string=current; DPEaselUpdateAddressField(body);
    NSCAssert([body.string isEqual:current],@"canvas text and unrelated fields are never rewritten");
    current=@"https://example.com"; field.string=current; DPEaselUpdateAddressField(field);
    NSCAssert([field.string isEqual:current],@"ordinary websites remain untouched");
    [DPEaselStore.shared flush]; [NSFileManager.defaultManager removeItemAtPath:root error:nil];
    puts("PASS: scoped native Easel names, rename propagation, unchanged-title dismissal, normal replacement navigation and disable restoration");
} }
