#import <AppKit/AppKit.h>
@class DPLibraryController;
@protocol DPLibrarySectionProvider <NSObject>
@property(readonly) NSString *title, *symbol;
- (BOOL)isEnabled;
- (NSView *)makeContent:(DPLibraryController *)controller;
- (void)reloadContent:(NSView *)content query:(NSString *)query;
- (void)primaryAction:(DPLibraryController *)controller;
@optional
- (NSInteger)sectionOrder;
- (NSString *)primaryActionTitle;
- (NSArray<NSButton *> *)headerButtonsForContent:(NSView *)content controller:(DPLibraryController *)controller;
@end
extern NSNotificationName const DPLibrarySectionsChanged;
void DPLibraryRegisterSection(id<DPLibrarySectionProvider> provider);
NSArray<NSString *> *DPLibrarySectionNames(void);
void DPLibraryBuildCategories(DPLibraryController *controller);
BOOL DPLibraryReloadCustomSection(DPLibraryController *controller);
void DPLibraryLayoutCustomSection(DPLibraryController *controller);
