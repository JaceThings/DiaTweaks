#import "Easels.h"
NSData *DPEaselPortableHTML(NSDictionary *snapshot,NSDictionary<NSString *,NSData *> *assets,NSData *preview,NSData *darkPreview,BOOL editable,NSError **error);
NSDictionary *DPEaselReadPortable(NSData *data,NSError **error);
@interface DPEaselStore (Portable)
- (void)importPortableURL:(NSURL *)url profile:(NSString *)profile completion:(void (^)(DPEaselDocument *,NSError *))completion;
- (void)importPortableURL:(NSURL *)url completion:(void (^)(DPEaselDocument *,NSError *))completion;
- (void)exportPortable:(DPEaselDocument *)document editable:(BOOL)editable toURL:(NSURL *)url completion:(void (^)(NSError *))completion;
@end
void DPEaselPresentImport(NSWindow *window);
