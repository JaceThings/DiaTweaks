#import "Patches/SidebarLibrary/Library.h"
BOOL DPIsKind(id object,const char *name) { return [[object identifier] isEqual:@(name)]; }
id DPSwiftValue(id object,NSString *key) { return nil; }
NSView *DPFindView(NSView *root,BOOL (^test)(NSView *)) { if(test(root))return root;for(NSView *v in root.subviews){NSView *found=DPFindView(v,test);if(found)return found;}return nil; }
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,100,100) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    NSView *tint=[NSView new];tint.identifier=@DPDiaWindowTint;tint.wantsLayer=YES;[window.contentView addSubview:tint];
    CAGradientLayer *gradient=[CAGradientLayer layer];[tint.layer addSublayer:gradient];
    for(NSAppearanceName appearance in @[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]) {
        window.appearance=[NSAppearance appearanceNamed:appearance];
        for(NSColor *color in @[NSColor.systemGreenColor,NSColor.systemPurpleColor,NSColor.systemOrangeColor]) {
            gradient.colors=@[(__bridge id)color.CGColor];
            NSColor *result=[DPLibraryAccentColor(window) colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            NSColor *rgb=[color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            NSCAssert(fabs(result.hueComponent-rgb.hueComponent)<.01,@"category hue follows each actual profile gradient");
            CGFloat target=[appearance isEqual:NSAppearanceNameDarkAqua] ? .90 : .48;
            NSCAssert(fabs(result.brightnessComponent-target)<.01,@"profile hue keeps contrast in each appearance");
        }
        gradient.colors=@[(__bridge id)NSColor.whiteColor.CGColor];
        NSCAssert([DPLibraryAccentColor(window) isEqual:NSColor.labelColor],@"white profiles use neutral readable icons rather than blue");
    }
    puts("PASS: live gradient changes, three accent hues, white profiles, and light/dark contrast");
} }
