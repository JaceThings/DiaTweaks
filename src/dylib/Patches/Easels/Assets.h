#import "Easels.h"
@interface DPEaselStore (Assets)
- (NSURL *)readableAssetURL:(NSString *)asset document:(NSString *)identifier;
- (NSURL *)assetURL:(NSString *)asset document:(NSString *)identifier;
- (NSDictionary *)imageInfoForAsset:(NSString *)asset document:(NSString *)identifier;
- (void)importImage:(NSURL *)url document:(DPEaselDocument *)document
        completion:(void (^)(NSString *asset,NSSize size,NSError *error))completion;
@end
@interface DPEaselStore (Discarding)
- (void)discardUnplacedAsset:(NSString *)asset document:(DPEaselDocument *)document;
@end
@interface DPEaselImageCache : NSObject
+ (instancetype)shared;
- (void)thumbnail:(NSURL *)url completion:(void (^)(NSImage *image))completion;
- (void)clear;
@end
