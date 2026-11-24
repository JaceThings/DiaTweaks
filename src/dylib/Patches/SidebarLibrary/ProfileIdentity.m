#import "Library.h"
// The scripting profile's name comes from the active space. Window.browserID
// and delayed browser attachments can still refer to a previous profile.
// Chromium's registry maps that name to the real data directory.
NSString *DPLibraryDirectoryForName(NSString *name) {
    if(!name.length) return nil;
    static NSDictionary *cached; static NSDate *modified; static NSNumber *size;
    NSString *support=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;
    NSString *path=[support stringByAppendingPathComponent:@"Dia/User Data/Local State"];
    NSDictionary *attributes=[NSFileManager.defaultManager attributesOfItemAtPath:path error:nil];
    if(!attributes || [attributes[NSFileSize] unsignedLongLongValue]>8*1024*1024) return nil;
    if(!cached || ![modified isEqual:attributes[NSFileModificationDate]] || ![size isEqual:attributes[NSFileSize]]) {
        NSData *data=[NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:nil];
        NSDictionary *root=data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
        id profile=[root isKindOfClass:NSDictionary.class] ? root[@"profile"] : nil;
        id registry=[profile isKindOfClass:NSDictionary.class] ? profile[@"info_cache"] : nil;
        if(![registry isKindOfClass:NSDictionary.class]) return nil;
        cached=registry; modified=attributes[NSFileModificationDate]; size=attributes[NSFileSize];
    }
    NSString *found=nil;
    for(NSString *directory in cached) {
        id entry=cached[directory];
        if(![entry isKindOfClass:NSDictionary.class] || ![entry[@"name"] isEqual:name]) continue;
        if(found || ![directory isEqual:directory.lastPathComponent]) return nil;
        found=directory;
    }
    return found;
}
