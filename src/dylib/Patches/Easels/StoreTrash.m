#import "StoreInternal.h"
#import "../SidebarLibrary/Retention.h"
@implementation DPEaselStore (Trash)
- (void)trash:(DPEaselDocument *)document completion:(void (^)(NSError *))completion {
    if (!document || document.deleted) { if(completion) completion(nil); return; }
    NSUInteger generation=[self.lifecycle[document.identifier] unsignedIntegerValue]+1; self.lifecycle[document.identifier]=@(generation);
    // Flag before queuing: a delayed editor save cannot recreate a deleted board.
    [document setDeleted:YES];
    NSURL *source=[self directory:document.identifier];
    NSURL *trash=[self.root URLByAppendingPathComponent:@"Trash" isDirectory:YES];
    NSURL *destination=[trash URLByAppendingPathComponent:document.identifier isDirectory:YES];
    [self.queue addOperationWithBlock:^{
        NSError *error=nil;
        BOOL made=[NSFileManager.defaultManager createDirectoryAtURL:trash withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:&error];
        if(made && DPLocalRecordDeletion(source,NSDate.date.timeIntervalSince1970,&error)) [NSFileManager.defaultManager moveItemAtURL:source toURL:destination error:&error];
        else if(!error) error=DPEaselError(@"The Easel could not be moved to Deleted.");
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            if(error && [self.lifecycle[document.identifier] unsignedIntegerValue]==generation) [document setDeleted:NO];
            if(!error) [NSNotificationCenter.defaultCenter postNotificationName:DPEaselCatalogChanged object:self];
            if(completion) completion(error);
        }];
    }];
}
- (void)restore:(DPEaselDocument *)document completion:(void (^)(NSError *))completion {
    if (!document.deleted) { if(completion) completion(nil); return; }
    NSUInteger generation=[self.lifecycle[document.identifier] unsignedIntegerValue]+1; self.lifecycle[document.identifier]=@(generation);
    [document setDeleted:NO];
    NSURL *source=[[self.root URLByAppendingPathComponent:@"Trash" isDirectory:YES] URLByAppendingPathComponent:document.identifier isDirectory:YES];
    NSURL *destination=[self directory:document.identifier];
    [self.queue addOperationWithBlock:^{
        NSError *error=nil;
        [NSFileManager.defaultManager moveItemAtURL:source toURL:destination error:&error];
        if(!error) [NSFileManager.defaultManager removeItemAtURL:DPLocalDeletionMarker(destination) error:nil];
        [NSOperationQueue.mainQueue addOperationWithBlock:^{
            if(error && [self.lifecycle[document.identifier] unsignedIntegerValue]==generation) [document setDeleted:YES];
            if(!error) [NSNotificationCenter.defaultCenter postNotificationName:DPEaselCatalogChanged object:self];
            if(completion) completion(error);
        }];
    }];
}
@end
