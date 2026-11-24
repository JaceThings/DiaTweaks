#import "Easels.h"
@interface DPEaselStore ()
@property NSURL *root;
@property NSOperationQueue *queue;
@property NSMapTable<NSString *,DPEaselDocument *> *documents;
@property NSMutableDictionary<NSString *,NSNumber *> *lifecycle;
@property NSCache<NSString *,NSDictionary *> *imageInfo;
@end
NSError *DPEaselError(NSString *message);
BOOL DPEaselWriteSnapshot(NSDictionary *snapshot, NSURL *directory, NSError **error);
