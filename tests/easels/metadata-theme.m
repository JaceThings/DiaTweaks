#import "Patches/Easels/HostInternal.h"
#import <stdio.h>
DPPatch DPEasels={.on=YES};
static NSString *root;
NSString *DPAppSupport(NSString *path) { return root; }
NSColor *DPLibraryAccentColor(NSWindow *window) { return NSColor.systemOrangeColor; }
void DPHook(const char *name,SEL selector,IMP replacement) {}
IMP DPOriginalIMP(id object,SEL selector,IMP replacement) { return NULL; }
@interface ThemeContents : NSObject
@property NSURL *url;
@property NSString *script;
@property NSUInteger executions;
@end
@implementation ThemeContents
- (void)executeJavascript:(NSString *)script completion:(void (^)(NSString *,BOOL))completion { self.script=script; self.executions++; completion(nil,YES); }
@end
static void settle(void) { [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.35]]; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication]; root=[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    DPEaselDocument *document=[DPEaselDocument documentWithSize:NSMakeSize(1000,1400)];
    ThemeContents *contents=ThemeContents.new; contents.url=[DPEaselStore.shared pageURL:document.identifier];
    DPEaselAttachment *attachment=DPEaselAttachment.new; attachment.contents=contents; attachment.document=document;
    NSView *pane=NSView.new; attachment.pane=pane; pane.appearance=[NSAppearance appearanceNamed:NSAppearanceNameAqua];
    DPEaselPublishTitle(attachment); settle(); NSString *light=attachment.publishedAppearance;
    NSCAssert(contents.executions==1 && [contents.script containsString:@"theme-color"] && [contents.script containsString:@"backgroundColor"],@"backing page advertises native canvas background to the tab strip");
    pane.appearance=[NSAppearance appearanceNamed:NSAppearanceNameDarkAqua]; DPEaselPublishTitle(attachment); settle();
    NSCAssert(contents.executions==2 && ![light isEqual:attachment.publishedAppearance] && [contents.script containsString:@"dark"],@"changing appearance updates tab background without renaming the board");
    DPEaselPublishTitle(attachment); settle(); NSCAssert(contents.executions==2,@"unchanged metadata does not poll or execute more scripts");
    puts("PASS: native Easel tab theme tracks light/dark canvas independently of title, with no repeated script work");
} }
