#import "Easels.h"
NSNotificationName const DPEaselChanged = @"DPEaselChanged";
NSNotificationName const DPEaselCatalogChanged = @"DPEaselCatalogChanged";

@implementation DPEaselDocument {
    NSDictionary *_metadata;
    NSArray<NSDictionary *> *_objects;
    NSString *_title;
    NSUInteger _revision;
    BOOL _deleted;
    NSUndoManager *_undo;
}
- (instancetype)initWithSnapshot:(NSDictionary *)snapshot {
    if (!DPEaselValidSnapshot(snapshot)) return nil;
    if ((self=[super init])) {
        NSData *data = [NSJSONSerialization dataWithJSONObject:snapshot options:0 error:nil];
        _metadata = DPEaselPrepareTitleSnapshot([NSJSONSerialization JSONObjectWithData:data options:0 error:nil]);
        _objects = _metadata[@"objects"]; _title=DPEaselTitle(_objects); _revision = [_metadata[@"revision"] unsignedIntegerValue];
        _undo=NSUndoManager.new; _undo.levelsOfUndo=100;
    }
    return self;
}
+ (instancetype)documentWithSize:(NSSize)size {
    size.width=MAX(320,MIN(16384,size.width)); size.height=MAX(320,MIN(16384,size.height));
    double now=NSDate.date.timeIntervalSince1970;
    return [[self alloc] initWithSnapshot:@{@"schema":@1,@"id":NSUUID.UUID.UUIDString,@"revision":@0,
        @"created":@(now),@"modified":@(now),@"titleModel":@2,@"size":@[@(size.width),@(size.height)],
        @"objects":@[DPEaselText(@"Untitled",NSMakeRect(MAX(24,(size.width-400)/2),32,MIN(400,size.width-48),88),0,YES)]}];
}
- (NSString *)profile { return [_metadata[@"profile"] isKindOfClass:NSString.class] ? _metadata[@"profile"] : @"Profile 1"; }
- (void)setProfile:(NSString *)profile {
    if(!profile.length || ![profile.lastPathComponent isEqual:profile] || [profile hasPrefix:@"."]) return;
    NSMutableDictionary *metadata=[_metadata mutableCopy]; metadata[@"profile"]=[profile copy]; _metadata=metadata;
}
- (NSString *)identifier { return _metadata[@"id"]; }
- (NSString *)title { return _title; }
- (NSArray *)objects { return _objects; }
- (NSUInteger)revision { return _revision; }
- (BOOL)deleted { return _deleted; }
- (NSUndoManager *)undo { return _undo; }
- (NSSize)canvasSize { return NSMakeSize([_metadata[@"size"][0] doubleValue],[_metadata[@"size"][1] doubleValue]); }
- (NSDictionary *)snapshot {
    NSMutableDictionary *snapshot=[_metadata mutableCopy]; snapshot[@"objects"]=_objects;
    snapshot[@"revision"]=@(_revision); snapshot[@"modified"]=@(NSDate.date.timeIntervalSince1970);
    return snapshot;
}
- (void)replaceObjects:(NSArray<NSDictionary *> *)objects action:(NSString *)action {
    NSAssert(NSThread.isMainThread,@"Document edits are main-thread transactions");
    if (_deleted || [_objects isEqual:objects]) return;
    NSMutableDictionary *candidate=[[self snapshot] mutableCopy]; candidate[@"objects"]=objects;
    if (!DPEaselValidSnapshot(candidate)) return;
    // Share unchanged immutable objects across revisions. A long undo history
    // must not duplicate every image/text/path record for a one-object move.
    NSMutableDictionary *prior=NSMutableDictionary.new;
    for(NSDictionary *object in _objects) prior[object[@"id"]]=object;
    NSMutableArray *next=NSMutableArray.new;
    for(NSDictionary *object in objects) {
        NSDictionary *previous=prior[object[@"id"]];
        if([previous isEqual:object]) [next addObject:previous];
        else {
            NSData *data=[NSJSONSerialization dataWithJSONObject:object options:0 error:nil];
            [next addObject:[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]];
        }
    }
    NSArray *owned=[next copy];
    NSArray *old=_objects;
    if(_undo.isUndoRegistrationEnabled) {
        [_undo registerUndoWithTarget:self handler:^(DPEaselDocument *document) { [document replaceObjects:old action:action]; }];
        [_undo setActionName:action ?: @"Edit Easel"];
    }
    _objects=owned; _title=DPEaselTitle(_objects); _revision++;
    [NSNotificationCenter.defaultCenter postNotificationName:DPEaselChanged object:self];
}
- (void)setDeleted:(BOOL)deleted {
    _deleted=deleted;
    [NSNotificationCenter.defaultCenter postNotificationName:DPEaselChanged object:self];
}
@end
