#import "LibraryUI.h"
#import "Patches/SidebarLibrary/Library.h"
@interface DPEaselLibraryProvider : NSObject <DPLibrarySectionProvider> @end
@implementation DPEaselLibraryProvider
- (NSString *)title { return @"Easels"; }
- (NSInteger)sectionOrder { return 100; }
- (NSString *)symbol { return @"pencil.and.outline"; }
- (BOOL)isEnabled { return DPEasels.on; }
- (NSString *)primaryActionTitle { return @"New Easel"; }
- (NSArray<NSButton *> *)headerButtonsForContent:(NSView *)content controller:(DPLibraryController *)controller { return @[((DPEaselLibraryContent *)content).importButton,((DPEaselLibraryContent *)content).recovery]; }
- (NSView *)makeContent:(DPLibraryController *)controller {
    DPEaselLibraryContent *view=DPEaselLibraryContent.new; view.library=controller; return view;
}
- (void)reloadContent:(NSView *)content query:(NSString *)query {
    DPEaselLibraryContent *view=(id)content; view.query=query ?: @"";
    view.allowed=DPEaselCanCreate(view.library.window) && view.library.context.length>0;
    if(![view.profile isEqual:view.library.context]) { view.profile=view.library.context; view.loaded=NO; view.generation++; view.records=@[]; }
    [view reload];
}
- (void)primaryAction:(DPLibraryController *)controller {
    NSWindow *window=controller.window; if(!DPEaselCanCreate(window)) return;
    [controller close]; DPEaselCreate(window);
}
@end
void DPEaselRegisterLibrary(void) { DPLibraryRegisterSection(DPEaselLibraryProvider.new); }
