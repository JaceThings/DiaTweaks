#import "Tasks.h"
@interface DPTaskStore ()
@property NSArray<NSDictionary *> *items,*cleared;
@property BOOL loaded;
@property NSError *error;
@property NSURL *root;
@property NSOperationQueue *queue;
- (void)save;
- (void)publish;
@end
BOOL DPTasksValidSnapshot(id snapshot);

NSArray *DPTasksDeleted(NSArray *items,NSTimeInterval now);
NSArray *DPTasksRestored(NSArray *items);
@interface DPTaskStore (Retention)
- (void)maintainRecovery;
@end
