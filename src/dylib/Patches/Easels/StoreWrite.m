#import "StoreInternal.h"
BOOL DPEaselWriteSnapshot(NSDictionary *snapshot,NSURL *directory,NSError **error) {
    if (!DPEaselValidSnapshot(snapshot)) { if(error) *error=DPEaselError(@"Invalid document snapshot"); return NO; }
    NSFileManager *files=NSFileManager.defaultManager;
    if (![files createDirectoryAtURL:directory withIntermediateDirectories:YES attributes:@{NSFilePosixPermissions:@0700} error:error]) return NO;
    NSURL *current=[directory URLByAppendingPathComponent:@"document.json"];
    NSData *previous=[NSData dataWithContentsOfURL:current];
    NSDictionary *old=previous ? [NSJSONSerialization JSONObjectWithData:previous options:0 error:nil] : nil;
    if (DPEaselValidSnapshot(old)) {
        if ([old[@"revision"] unsignedIntegerValue]>[snapshot[@"revision"] unsignedIntegerValue]) return YES;
        if (![previous writeToURL:[directory URLByAppendingPathComponent:@"recovery.json"] options:NSDataWritingAtomic error:error]) return NO;
    }
    NSData *data=[NSJSONSerialization dataWithJSONObject:snapshot options:0 error:error];
    if (!data || ![data writeToURL:current options:NSDataWritingAtomic error:error]) return NO;
    NSString *displayTitle=DPEaselDisplayTitle(DPEaselTitle(snapshot[@"objects"]));
    NSDictionary *summary=@{@"id":snapshot[@"id"],@"title":displayTitle,@"modified":snapshot[@"modified"],@"revision":snapshot[@"revision"],@"profile":snapshot[@"profile"] ?: @"Profile 1"};
    NSData *index=[NSJSONSerialization dataWithJSONObject:summary options:0 error:error];
    if(!index || ![index writeToURL:[directory URLByAppendingPathComponent:@"summary.json"] options:NSDataWritingAtomic error:error]) return NO;
    NSString *title=DPEaselEscapeHTML(displayTitle);
    NSString *html=[NSString stringWithFormat:@"<!doctype html><html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width'><meta http-equiv='Content-Security-Policy' content=\"default-src 'none'; style-src 'unsafe-inline'\"><title>%@</title><style>:root{color-scheme:light dark}body{font:17px system-ui;margin:64px;max-width:44em;color:CanvasText;background:Canvas}h1{color:CanvasText}</style></head><body><h1>%@</h1><p>This is a local Easel. Enable Easels in DiaTweaks to edit it. Your document and images are stored beside this page.</p></body></html>",title,title];
    return [html writeToURL:[directory URLByAppendingPathComponent:@"index.html"] atomically:YES encoding:NSUTF8StringEncoding error:error];
}
