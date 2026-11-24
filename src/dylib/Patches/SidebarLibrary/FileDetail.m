#import "Library.h"
#import <objc/message.h>
BOOL DPLibraryIsEaselFile(DPLibraryFile *file) {
    if (!file.archived) return NO;
    Class cls = NSClassFromString(@"DPEaselStore");
    SEL shared = NSSelectorFromString(@"shared"), identify = NSSelectorFromString(@"identifierForURL:");
    id store = [cls respondsToSelector:shared] ? ((id (*)(id, SEL))objc_msgSend)(cls, shared) : nil;
    return [store respondsToSelector:identify] && ((id (*)(id, SEL, id))objc_msgSend)(store, identify, [NSURL URLWithString:file.source]) != nil;
}
BOOL DPLibraryIsMovieURL(NSURL *url);
NSString *DPLibraryRemainingTime(long long seconds) {
    if(seconds<=0) return @"";
    if(seconds<60) return [NSString stringWithFormat:@"%lld sec remaining",seconds];
    long long minutes=seconds/60+(seconds%60!=0);
    if(minutes<60) return [NSString stringWithFormat:@"%lld min remaining",minutes];
    long long hours=minutes/60,rest=minutes%60;
    if(hours<24) return rest ? [NSString stringWithFormat:@"%lld hr %lld min remaining",hours,rest] : [NSString stringWithFormat:@"%lld hr remaining",hours];
    long long days=hours/24; hours%=24;
    return hours ? [NSString stringWithFormat:@"%lld d %lld hr remaining",days,hours] : [NSString stringWithFormat:@"%lld d remaining",days];
}
NSString *DPLibraryFileDetail(DPLibraryFile *file) {
    NSURL *url = file.source.length ? [NSURL URLWithString:file.source] : nil;
    NSString *host = url.host ?: @""; if ([host hasPrefix:@"www."]) host = [host substringFromIndex:4];
    if (DPLibraryIsEaselFile(file)) return @"Easel";
    if (file.archived) return host.length ? [host stringByAppendingString:[url.path isEqual:@"/"] ? @"" : url.path ?: @""] : file.source ?: @"";
    if (file.state == 1) {
        NSString *done = [NSByteCountFormatter stringFromByteCount:MAX(0,file.completed) countStyle:NSByteCountFormatterCountStyleFile];
        NSString *total = file.total > 0 ? [NSByteCountFormatter stringFromByteCount:file.total countStyle:NSByteCountFormatterCountStyleFile] : @"?";
        NSString *time = file.remaining > 0 ? [@" · " stringByAppendingString:DPLibraryRemainingTime(file.remaining)] : @"";
        return [NSString stringWithFormat:@"%@%@ / %@%@",file.paused ? @"Paused · " : @"Downloading · ",done,total,time];
    }
    if (file.missing) return @"File moved or deleted";
    if (file.state == 4) return @"Download interrupted";
    NSString *fileKind = DPLibraryIsMedia(file) ? (DPLibraryIsMovieURL([NSURL fileURLWithPath:file.path]) ? @"Video" : @"Image") : @"Download";
    return host.length ? [NSString stringWithFormat:@"%@ from %@",fileKind,host] : fileKind;
}
