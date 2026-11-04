#import "TabIntegrations.h"

@interface NSObject (DPTabIntegrationFields)
- (id)safeSwiftValueForKey:(NSString *)key;
@end

NSArray<NSValue *> *DPRegisteredTabIntegrations(void);
DPTabIntegration *DPTabIntegrationForURL(id value);  // Enabled, unambiguous match only.
BOOL DPTabIntegrationEnabled(DPTabIntegration *integration);
NSArray *DPIntegrationTabsInWindow(NSWindow *window);

void DPInstallIntegrationPages(void);
void DPRememberIntegrationPage(id contents, id browser);
void DPApplyIntegrationPages(void);
void DPDisposeIntegrationPage(DPTabIntegrationPage *page);
void DPInvalidateIntegrationPageCache(DPTabIntegrationPage *page);
void DPInstallIntegrationHover(void);
void DPApplyIntegrationHover(void);
NSString *DPVerifyIntegrationHover(DPTabIntegration *integration);
void DPAttachIntegrationHover(NSView *view);
void DPDetachIntegrationHover(NSView *view);
void DPDismissIntegrationHover(void);
BOOL DPReplacesIntegrationHoverWindow(NSWindow *window);
BOOL DPIntegrationHostAvailable(void);
void DPInstallIntegrationHost(void);

@interface DPTabIntegrationHost : NSObject
@property(nonatomic, readonly) NSWindow *window;
- (instancetype)initWithPreview:(DPTabIntegrationPreview *)preview anchor:(NSView *)anchor;
- (void)show;
- (void)close;
- (BOOL)containsPointer;
@end
