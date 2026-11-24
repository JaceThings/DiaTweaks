#import "Library.h"
#import <sqlite3.h>
#import <dlfcn.h>
NSImage *DPLibraryFaviconFromDatabase(NSString *profile,NSURL *url) {
    if(!profile.length || ![profile.lastPathComponent isEqual:profile] || !url.host.length) return nil;
    static void *library; static dispatch_once_t once;
    dispatch_once(&once,^{ library=dlopen("/usr/lib/libsqlite3.dylib",RTLD_LAZY); }); if(!library) return nil;
    int (*openDB)(const char *,sqlite3 **,int,const char *)=dlsym(library,"sqlite3_open_v2");
    int (*prepare)(sqlite3 *,const char *,int,sqlite3_stmt **,const char **)=dlsym(library,"sqlite3_prepare_v2");
    int (*bind)(sqlite3_stmt *,int,const char *,int,void (*)(void *))=dlsym(library,"sqlite3_bind_text");
    int (*step)(sqlite3_stmt *)=dlsym(library,"sqlite3_step");
    const void *(*blob)(sqlite3_stmt *,int)=dlsym(library,"sqlite3_column_blob");
    int (*bytes)(sqlite3_stmt *,int)=dlsym(library,"sqlite3_column_bytes");
    int (*finalize)(sqlite3_stmt *)=dlsym(library,"sqlite3_finalize");
    int (*closeDB)(sqlite3 *)=dlsym(library,"sqlite3_close");
    if(!openDB || !prepare || !bind || !step || !blob || !bytes || !finalize || !closeDB) return nil;
    NSString *support=NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory,NSUserDomainMask,YES).firstObject;
    NSString *path=[support stringByAppendingPathComponent:[NSString stringWithFormat:@"Dia/User Data/%@/Favicons",profile]];
    sqlite3 *database=NULL; if(openDB(path.fileSystemRepresentation,&database,SQLITE_OPEN_READONLY|SQLITE_OPEN_NOMUTEX,NULL)!=SQLITE_OK) { if(database) closeDB(database); return nil; }
    NSData *data=nil;
    for(NSNumber *exact in @[@YES,@NO]) {
        const char *query=exact.boolValue ? "SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id=m.icon_id WHERE m.page_url=? ORDER BY b.width DESC LIMIT 1" :
            "SELECT b.image_data FROM icon_mapping m JOIN favicon_bitmaps b ON b.icon_id=m.icon_id WHERE m.page_url LIKE ? ESCAPE '\\' ORDER BY b.width DESC LIMIT 1";
        sqlite3_stmt *statement=NULL;
        if(prepare(database,query,-1,&statement,NULL)==SQLITE_OK) {
            NSURLComponents *origin=[NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO]; origin.path=@"/"; origin.query=nil; origin.fragment=nil; origin.user=nil; origin.password=nil;
            NSString *prefix=[[origin.URL.absoluteString stringByReplacingOccurrencesOfString:@"%" withString:@"\\%"] stringByReplacingOccurrencesOfString:@"_" withString:@"\\_"];
            NSString *value=exact.boolValue ? url.absoluteString : [prefix stringByAppendingString:@"%"];
            bind(statement,1,value.UTF8String,-1,SQLITE_TRANSIENT);
            if(step(statement)==SQLITE_ROW && bytes(statement,0)>0 && bytes(statement,0)<4*1024*1024) data=[NSData dataWithBytes:blob(statement,0) length:bytes(statement,0)];
        }
        if(statement) finalize(statement); if(data) break;
    }
    closeDB(database); return data ? [[NSImage alloc] initWithData:data] : nil;
}
