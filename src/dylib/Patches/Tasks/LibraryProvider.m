#import "TaskView.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import <objc/message.h>
static BOOL DPTasksNormalWindow(NSWindow *window) {
    id browser=DPBrowserOfWindow(window); SEL context=NSSelectorFromString(@"context"),identity=NSSelectorFromString(@"id"),incognito=NSSelectorFromString(@"isIncognito");
    id profile=[browser respondsToSelector:context] ? ((id (*)(id,SEL))objc_msgSend)(browser,context) : nil;
    id value=[profile respondsToSelector:identity] ? ((id (*)(id,SEL))objc_msgSend)(profile,identity) : nil;
    return value && [value respondsToSelector:incognito] && !((BOOL (*)(id,SEL))objc_msgSend)(value,incognito);
}
@interface DPTaskProvider : NSObject <DPLibrarySectionProvider> @end
@implementation DPTaskProvider
- (NSString *)title { return @"Tasks"; }
- (NSInteger)sectionOrder { return 0; }
- (NSString *)symbol { return @"checklist"; }
- (BOOL)isEnabled { return DPTasks.on; }
- (NSString *)primaryActionTitle { return nil; }
- (NSView *)makeContent:(DPLibraryController *)controller {
    DPTaskContent *content=DPTaskContent.new; content.library=controller; content.allowed=DPTasksNormalWindow(controller.window); content.store=content.allowed ? [DPTaskStore storeForProfile:controller.context] : nil;
    controller.preferredSectionResponder=content.input; return content;
}
- (NSArray<NSButton *> *)headerButtonsForContent:(NSView *)content controller:(DPLibraryController *)controller {
    DPTaskContent *tasks=(id)content; return @[tasks.filterButton,tasks.optionsButton];
}
- (void)reloadContent:(NSView *)content query:(NSString *)query {
    DPTaskContent *tasks=(id)content; tasks.allowed=DPTasksNormalWindow(tasks.library.window); DPTaskStore *store=tasks.allowed ? [DPTaskStore storeForProfile:tasks.library.context] : nil;
    if(tasks.store!=store) { tasks.store=store; [tasks.pending removeAllObjects]; tasks.removing=NO; }
    tasks.query=query ?: @""; [tasks reload];
}
- (void)primaryAction:(DPLibraryController *)controller { [controller.window makeFirstResponder:((DPTaskContent *)controller.customContent).input]; }
@end
void DPTasksRegisterLibrary(void) { DPLibraryRegisterSection(DPTaskProvider.new); }
