#import "Components.h"
@class DPTabIntegrationListPreview;

NSView *DPIntegrationListMakeRow(DPTabIntegrationItem *item, DPTabIntegrationListPreview *preview,
                               BOOL cached, CGFloat height);
void DPIntegrationListPopulateRow(NSView *row, DPTabIntegrationItem *item, DPTabIntegrationListPreview *preview, BOOL cached);
NSButton *DPIntegrationListMakeActionButton(DPTabIntegrationAction *action, DPTabIntegrationItem *item, NSRect frame,
                                          DPTabIntegrationListPreview *preview, BOOL cached);
NSButton *DPIntegrationListMakeMoreActionsButton(NSArray<DPTabIntegrationAction *> *actions, DPTabIntegrationItem *item,
                                               NSRect frame, DPTabIntegrationListPreview *preview, BOOL cached);
void DPIntegrationListPerformAction(NSButton *button, DPTabIntegrationContext *context);
void DPIntegrationListPerformMenuAction(NSMenuItem *item, DPTabIntegrationContext *context);
DPTabIntegrationListContent *DPIntegrationListSafeContent(id candidate);
NSArray *DPIntegrationListSignature(DPTabIntegrationListContent *content, NSString *emptyMessage);
NSSize DPIntegrationListFitContent(NSView *view, CGFloat height, CGFloat maximumHeight);
