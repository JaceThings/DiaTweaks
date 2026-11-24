#import "StdPatch/StdPatch.h"
extern DPPatch DPTasks;
extern NSNotificationName const DPTasksChanged;
@interface DPTaskStore : NSObject
@property(readonly) NSArray<NSDictionary *> *items,*cleared;
@property(readonly) BOOL loaded;
@property(readonly) NSError *error;
+ (instancetype)shared;
+ (instancetype)storeForProfile:(NSString *)profile;
+ (void)flushAll;
- (instancetype)initWithRoot:(NSURL *)root;
- (BOOL)add:(NSString *)text;
- (void)setCompleted:(BOOL)completed identifier:(NSString *)identifier;
- (void)clear;
- (void)restoreCleared;
- (void)flush;
@end
@interface DPTaskStore (Editing)
- (void)edit:(NSString *)text identifier:(NSString *)identifier;
- (void)remove:(NSString *)identifier;
- (void)restore:(NSString *)identifier;
- (void)clearCompleted;
@end
void DPTasksRegisterLibrary(void);
