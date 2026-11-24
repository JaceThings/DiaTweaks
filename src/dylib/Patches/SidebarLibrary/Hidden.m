#import "Library.h"
static NSString *DPHiddenKey(BOOL archive) { return archive ? @"sidebarLibraryHiddenArchive" : @"sidebarLibraryHiddenFiles"; }
NSSet *DPLibraryHiddenIDs(NSString *profile,BOOL archive) {
    if (!profile.length) return NSSet.set;
    id values=[[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"] dictionaryForKey:DPHiddenKey(archive)][profile];
    return [values isKindOfClass:NSArray.class] ? [NSSet setWithArray:values] : NSSet.set;
}
void DPLibrarySetHidden(NSString *profile,NSArray<DPLibraryFile *> *files,BOOL hidden) {
    if (!profile.length) return;
    NSMutableArray *local=NSMutableArray.new; NSMutableDictionary *others=NSMutableDictionary.new;
    for(DPLibraryFile *file in files) {
        if(file.profile.length && ![file.profile isEqual:profile]) {
            if(!others[file.profile]) others[file.profile]=NSMutableArray.new;
            [others[file.profile] addObject:file];
        } else [local addObject:file];
    }
    for(NSString *owner in others) DPLibrarySetHidden(owner,others[owner],hidden);
    files=local;
    NSUserDefaults *settings=[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    for (NSNumber *archived in @[@NO,@YES]) {
        NSString *key=DPHiddenKey(archived.boolValue);
        NSMutableDictionary *profiles=[[settings dictionaryForKey:key] mutableCopy] ?: NSMutableDictionary.new;
        NSMutableSet *ids=[DPLibraryHiddenIDs(profile,archived.boolValue) mutableCopy];
        for (DPLibraryFile *file in files) if (file.archived==archived.boolValue && file.identifier.length) {
            if (hidden) [ids addObject:file.identifier]; else [ids removeObject:file.identifier];
        }
        profiles[profile]=ids.allObjects; [settings setObject:profiles forKey:key];
    }
    [NSNotificationCenter.defaultCenter postNotificationName:DPLibraryDownloadsChanged object:nil];
}
void DPLibraryRestoreHidden(NSString *profile,BOOL archive) {
    if (!profile.length) return;
    NSUserDefaults *settings=[[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    NSMutableDictionary *profiles=[[settings dictionaryForKey:DPHiddenKey(archive)] mutableCopy];
    [profiles removeObjectForKey:profile]; [settings setObject:profiles ?: @{} forKey:DPHiddenKey(archive)];
    [NSNotificationCenter.defaultCenter postNotificationName:DPLibraryDownloadsChanged object:nil];
}
