#import "StdPatch/StdPatch.h"

extern DPPatch DPEasels;
extern NSNotificationName const DPEaselChanged;
extern NSNotificationName const DPEaselCatalogChanged;
BOOL DPEaselUUID(NSString *value);
BOOL DPEaselValidSnapshot(NSDictionary *snapshot);
NSString *DPEaselTitle(NSArray<NSDictionary *> *objects);
NSDictionary *DPEaselPrepareTitleSnapshot(NSDictionary *snapshot);
NSString *DPEaselDisplayTitle(NSString *title);
NSString *DPEaselEscapeHTML(NSString *text);
NSDictionary *DPEaselText(NSString *text, NSRect frame, NSUInteger order, BOOL placeholder);

@interface DPEaselDocument : NSObject
@property(readonly, copy) NSString *identifier;
@property(readonly, copy) NSString *title;
@property(copy) NSString *profile;
@property(readonly, copy) NSArray<NSDictionary *> *objects;
@property(readonly) NSSize canvasSize;
@property(readonly) NSUInteger revision;
@property(readonly) BOOL deleted;
@property(readonly) NSUndoManager *undo;
- (instancetype)initWithSnapshot:(NSDictionary *)snapshot;
+ (instancetype)documentWithSize:(NSSize)size;
- (NSDictionary *)snapshot;
- (void)replaceObjects:(NSArray<NSDictionary *> *)objects action:(NSString *)action;
- (void)setDeleted:(BOOL)deleted;

@end

@interface DPEaselDocument (Renaming)
- (void)rename:(NSString *)name;
@end

@interface DPEaselStore : NSObject
@property(readonly) NSURL *root;
+ (instancetype)shared;
- (instancetype)initWithRoot:(NSURL *)root;
- (NSURL *)directory:(NSString *)identifier;
- (NSURL *)pageURL:(NSString *)identifier;
- (NSString *)identifierForURL:(NSURL *)url;
- (DPEaselDocument *)cachedDocumentForURL:(NSURL *)url;
- (void)save:(DPEaselDocument *)document completion:(void (^)(NSError *))completion;
- (void)flush;
@end
@interface DPEaselStore (Loading)
- (DPEaselDocument *)load:(NSString *)identifier error:(NSError **)error;
- (DPEaselDocument *)loadTrashed:(NSString *)identifier error:(NSError **)error;
@end
@interface DPEaselStore (Listing)
- (void)list:(void (^)(NSArray<NSDictionary *> *records,NSError *error))completion;
- (void)listTrashed:(void (^)(NSArray<NSDictionary *> *records,NSError *error))completion;
@end
@interface DPEaselStore (Trash)
- (void)trash:(DPEaselDocument *)document completion:(void (^)(NSError *))completion;
- (void)restore:(DPEaselDocument *)document completion:(void (^)(NSError *))completion;
@end

@interface DPEaselHost : NSObject
+ (void)install;
+ (void)refresh;
+ (void)finishEditing;
+ (void)finishEditingDocument:(DPEaselDocument *)document;
@end
NSView *DPEaselEditor(DPEaselDocument *document);
BOOL DPEaselCanCreate(NSWindow *window);
BOOL DPEaselOpen(NSWindow *window,DPEaselDocument *document);
void DPEaselCreate(NSWindow *window);
void DPEaselInstallCreateMenu(void);
void DPEaselRegisterLibrary(void);
void DPEaselInstallTabMenus(void);
void DPEaselRegisterAddressTitle(void);
void DPEaselPresentRename(NSWindow *window,DPEaselDocument *document);
void DPEaselTrashDocument(DPEaselDocument *document,void (^completion)(NSError *));
void DPEaselDeleteFromTab(NSWindow *window,DPEaselDocument *document);
