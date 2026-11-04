#import "TabIntegrations.h"

NS_ASSUME_NONNULL_BEGIN

@class DPTabIntegrationContext;
@class DPTabIntegrationItem;

typedef void (^DPTabIntegrationActionHandler)(DPTabIntegrationContext *context, DPTabIntegrationItem *item);
typedef NSView * _Nullable (^DPTabIntegrationItemViewProvider)(DPTabIntegrationItem *item, DPTabIntegrationContext *context);

// An action belongs to an item, so integrations can expose any number of meaningful controls.
// A symbol name is optional; without one, the title is shown in a compact text button.
@interface DPTabIntegrationAction : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *symbolName;
@property(nonatomic, copy, nullable) NSString *accessibilityTitle;
@property(nonatomic) BOOL enabled;
@property(nonatomic) BOOL enabledWhenCached;
@property(nonatomic, copy, nullable) DPTabIntegrationActionHandler handler;
- (instancetype)initWithTitle:(NSString *)title handler:(nullable DPTabIntegrationActionHandler)handler;
@end

@interface DPTabIntegrationItem : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *identifier;
@property(nonatomic, strong, nullable) id representedObject; // Optional provider-owned payload for views/actions.
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, copy, nullable) NSString *statusText;
@property(nonatomic, copy, nullable) NSString *toolTip;
@property(nonatomic) BOOL working;
@property(nonatomic) BOOL unread;
@property(nonatomic) BOOL pinned;
@property(nonatomic, strong, nullable) DPTabIntegrationAction *primaryAction;
@property(nonatomic, copy) NSArray<DPTabIntegrationAction *> *actions;
// Return a custom row view to replace the standard title/subtitle/status/action layout.
@property(nonatomic, copy, nullable) DPTabIntegrationItemViewProvider viewProvider;
- (instancetype)initWithTitle:(NSString *)title;
@end

@interface DPTabIntegrationListContent : NSObject
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy) NSArray<DPTabIntegrationItem *> *items;
@property(nonatomic, copy, nullable) NSString *emptyMessage;
@property(nonatomic, copy, nullable) NSString *footerMessage;
// Common values: loading, live, cached, empty, unavailable, signedOut, unsupported.
@property(nonatomic, copy) NSString *state;
@property(nonatomic) CGFloat maximumHeight; // Default 420; zero leaves height unconstrained.
// Set when custom view data changes without any standard item fields changing.
@property(nonatomic, copy, nullable) NSString *revision;
// Optional trailing status such as "Cached"; defaults to "Cached" for cached state.
@property(nonatomic, copy, nullable) NSString *statusText;
- (instancetype)initWithTitle:(NSString *)title items:(NSArray<DPTabIntegrationItem *> *)items;
@end

NS_ASSUME_NONNULL_END

// Shared bounded loading message and ordinary empty-state copy for integrations.
NS_ASSUME_NONNULL_BEGIN
NSString * _Nonnull DPTabIntegrationDefaultEmptyMessage(NSString * _Nonnull state, NSTimeInterval elapsed);
NS_ASSUME_NONNULL_END
