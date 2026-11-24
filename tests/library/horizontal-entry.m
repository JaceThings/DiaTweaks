#import "Patches/SidebarLibrary/Library.h"
DPPatch DPSidebarLibrary;
static NSView *fixtureRoot;
id DPGet(id object,const void *key) { return objc_getAssociatedObject(object,key); }
void DPSet(id object,const void *key,id value) { objc_setAssociatedObject(object,key,value,OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
BOOL DPIsKind(id object,const char *name) { return [[object identifier] isEqual:@(name)]; }
NSView *DPFindView(NSView *root,BOOL (^test)(NSView *)) { if(test(root))return root;for(NSView *v in root.subviews){NSView *found=DPFindView(v,test);if(found)return found;}return nil; }
NSArray *DPFindViews(const char *name) { return @[fixtureRoot]; }
NSButton *DPLibraryMakeEntryButton(NSString *identifier) { NSButton *button=[NSButton new];button.identifier=identifier;return button; }
#import "Patches/SidebarLibrary/Horizontal.m"
@interface LibraryFixtureButton : NSButton @end
@implementation LibraryFixtureButton @end
@interface LibraryFeatheredContainerView : NSView @end
@implementation LibraryFeatheredContainerView @end
int main(void) { @autoreleasepool {
    [NSApplication sharedApplication];
    NSWindow *window=[[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,1000,700) styleMask:0 backing:NSBackingStoreBuffered defer:NO];
    fixtureRoot=[[NSView alloc] initWithFrame:NSMakeRect(0,0,1000,42)];[window.contentView addSubview:fixtureRoot];
    NSView *tabs=[[LibraryFeatheredContainerView alloc] initWithFrame:NSMakeRect(92,0,908,62)];[fixtureRoot addSubview:tabs];
    NSMutableArray *controls=[NSMutableArray new];
    for(NSUInteger i=0;i<3;i++){NSView *view=[[LibraryFixtureButton alloc] initWithFrame:NSMakeRect(878+i*42,5,32,32)];[fixtureRoot addSubview:view];[controls addObject:view];}
    DPSidebarLibrary.on=YES;
    for(NSUInteger bits=0;bits<8;bits++)for(NSUInteger pass=0;pass<10;pass++) {
        DPRestoreLibraryStrip(fixtureRoot);
        for(NSUInteger i=0;i<3;i++)[controls[i] setHidden:!(bits&(1<<i))];
        DPPlaceLibraryStrip(fixtureRoot);
        DPLibraryStripState *state=DPGet(fixtureRoot,&DPLibraryStripKey);
        NSCAssert(DPLibraryVerifyHorizontal(YES)==nil,@"live header verifier sees a valid entry and no overlapping controls");
        NSCAssert(state.button.superview==fixtureRoot,@"entry survives every native icon visibility combination");
        NSCAssert(NSMaxX(tabs.frame)<=NSMinX(state.button.frame),@"tab viewport reserves the Library slot");
        for(NSView *view in controls)if(!view.hidden)NSCAssert(!NSIntersectsRect(view.frame,state.button.frame),@"native controls do not overlap Library");
        NSCAssert(NSMinX(state.button.frame)>=92 && NSMaxX(state.button.frame)<=1000,@"entry stays in the header");
    }
    DPRestoreLibraryStrip(fixtureRoot);
    tabs.frame=NSMakeRect(92,0,908,0); DPPlaceLibraryStrip(fixtureRoot);
    NSRect nativeFinished=tabs.frame; nativeFinished.origin.y=3; nativeFinished.size.height=62; tabs.frame=nativeFinished;
    DPRestoreLibraryStrip(fixtureRoot);
    NSCAssert(NSHeight(tabs.frame)==62 && NSMinY(tabs.frame)==3,@"restoring horizontal reservation preserves late native clipping height and y");
    DPRestoreLibraryStrip(fixtureRoot); DPSidebarLibrary.on=NO;DPPlaceLibraryStrip(fixtureRoot);
    NSCAssert(NSWidth(tabs.frame)==908 && !DPGet(fixtureRoot,&DPLibraryStripKey),@"off restores tab viewport and removes entry");
    DPSidebarLibrary.on=YES;NSView *footer=[NSView new];footer.identifier=@DPDiaSidebarFooter;[window.contentView addSubview:footer];DPPlaceLibraryStrip(fixtureRoot);
    NSCAssert(!DPGet(fixtureRoot,&DPLibraryStripKey),@"vertical window has no horizontal duplicate");
    puts("PASS: 80 repeated header layouts, all eight native icon combinations, tab reservation, off cleanup and vertical isolation");
} }
