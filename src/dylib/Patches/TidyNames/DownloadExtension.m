#import "StdPatch/StdPatch.h"
#import "DownloadBridge.h"
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>

void DPTidyUnregisterDownloadExtension(void) {
    NSString *path = DPAppSupport(DPTidyDownloadManifest);
    if (DPTidyDownloadManifestOwned(path, DPAppSupport(@"DiaPatches/bin/diapatch")))
        [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

static BOOL DPTidyWriteDownloadAsset(NSData *data, NSString *path) {
    return data &&
        [NSFileManager.defaultManager createDirectoryAtPath:path.stringByDeletingLastPathComponent
                               withIntermediateDirectories:YES attributes:nil error:nil] &&
        [data writeToFile:path options:NSDataWritingAtomic error:nil];
}

BOOL DPTidyLoadDownloadExtension(void) {
    NSString *folder = DPAppSupport(@"DiaPatches/" DPTidyDownloadExtensionFolder);
    NSString *helper = DPAppSupport(@"DiaPatches/bin/diapatch");
    NSString *manifest = DPAppSupport(DPTidyDownloadManifest);
    NSFileManager *files = NSFileManager.defaultManager;
    if (![files isExecutableFileAtPath:helper] ||
        ([files fileExistsAtPath:manifest] && !DPTidyDownloadManifestOwned(manifest, helper))) return NO;

    for (NSString *name in @[@"manifest.json", @"worker.js"]) {
        NSString *section = [@"__td_" stringByAppendingString:name.stringByDeletingPathExtension];
        unsigned long size = 0;
        uint8_t *bytes = getsectiondata(&_mh_dylib_header, "__TEXT", section.UTF8String, &size);
        if (!bytes || !DPTidyWriteDownloadAsset([NSData dataWithBytes:bytes length:size],
                                               [folder stringByAppendingPathComponent:name])) return NO;
    }
    NSData *host = [NSJSONSerialization dataWithJSONObject:@{
        @"name": DPTidyDownloadHost, @"description": @"DiaTweaks Tidy Downloads",
        @"type": @"stdio", @"path": helper,
        @"allowed_origins": @[@DPTidyDownloadExtensionOrigin],
    } options:0 error:nil];
    if (!DPTidyWriteDownloadAsset(host, manifest)) return NO;
    DPLoadExtension(folder);
    return YES;
}
