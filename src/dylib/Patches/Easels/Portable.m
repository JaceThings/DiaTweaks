#import "Portable.h"
#import "StoreInternal.h"
#import "ImageIO.h"
static NSString *const DPPrefix=@"<script id=\"diatweaks-easel\" type=\"application/octet-stream\">";
static const NSUInteger DPPortableLimit=128*1024*1024;
NSData *DPEaselPortableHTML(NSDictionary *snapshot,NSDictionary<NSString *,NSData *> *assets,NSData *preview,NSData *darkPreview,BOOL editable,NSError **error) {
    if(!DPEaselValidSnapshot(snapshot) || !preview.length) { if(error) *error=DPEaselError(@"The Easel could not be exported."); return nil; }
    NSString *title=DPEaselEscapeHTML(DPEaselDisplayTitle(DPEaselTitle(snapshot[@"objects"])));
    NSString *payload=@"";
    if(editable) {
        NSMutableDictionary *encoded=NSMutableDictionary.new;
        for(NSString *key in assets) encoded[key]=[assets[key] base64EncodedStringWithOptions:0];
        NSData *json=[NSJSONSerialization dataWithJSONObject:@{@"format":@"DiaTweaks.Easel",@"version":@1,@"document":snapshot,@"assets":encoded} options:0 error:error];
        if(!json) return nil;
        payload=[NSString stringWithFormat:@"%@%@</script>",DPPrefix,[json base64EncodedStringWithOptions:0]];
    }
    NSString *html=[NSString stringWithFormat:@"<!doctype html><html><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width\"><meta http-equiv=\"Content-Security-Policy\" content=\"default-src 'none'; img-src data:; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'\"><title>%@</title><style>html{color-scheme:light dark;background:Canvas;color:CanvasText}body{margin:24px auto;max-width:1600px;font:14px system-ui;color:inherit}img{display:block;width:100%%;height:auto}p{padding:0 16px}</style></head><body><picture><source media=\"(prefers-color-scheme: dark)\" srcset=\"data:image/png;base64,%@\"><img alt=\"%@\" src=\"data:image/png;base64,%@\"></picture><p>%@</p>%@</body></html>",title,[(darkPreview ?: preview) base64EncodedStringWithOptions:0],title,[preview base64EncodedStringWithOptions:0],editable ? @"Editable Easel copy · Open in Dia with Easels enabled, or import this file from Library → Easels." : @"Easel preview · This file contains no editable board data.",payload];
    NSData *result=[html dataUsingEncoding:NSUTF8StringEncoding];
    if(result.length>DPPortableLimit) { if(error) *error=DPEaselError(@"This Easel is too large for a portable file (128 MB limit)."); return nil; } return result;
}
NSDictionary *DPEaselReadPortable(NSData *data,NSError **error) {
    NSString *reason=@"Choose an editable .easel file exported from DiaTweaks.";
    NSString *html=data.length<=DPPortableLimit ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
    NSRange start=[html rangeOfString:DPPrefix];
    if(html && start.location!=NSNotFound) {
        NSUInteger offset=NSMaxRange(start); NSRange end=[html rangeOfString:@"</script>" options:0 range:NSMakeRange(offset,html.length-offset)];
        NSData *json=end.location!=NSNotFound ? [[NSData alloc] initWithBase64EncodedString:[html substringWithRange:NSMakeRange(offset,end.location-offset)] options:0] : nil;
        id envelope=json ? [NSJSONSerialization JSONObjectWithData:json options:0 error:nil] : nil;
        if([envelope isKindOfClass:NSDictionary.class] && [envelope[@"format"] isEqual:@"DiaTweaks.Easel"] && [envelope[@"version"] isEqual:@1] && DPEaselValidSnapshot(envelope[@"document"]) && [envelope[@"assets"] isKindOfClass:NSDictionary.class]) {
            NSMutableSet *required=NSMutableSet.new; for(NSDictionary *object in envelope[@"document"][@"objects"]) if([object[@"type"] isEqual:@"image"]) [required addObject:object[@"asset"]];
            NSMutableDictionary *assets=NSMutableDictionary.new; NSUInteger total=0;
            if([envelope[@"assets"] count]!=required.count) goto failed;
            for(NSString *key in required) {
                id value=envelope[@"assets"][key]; if(![value isKindOfClass:NSString.class]) goto failed;
                NSData *bytes=[[NSData alloc] initWithBase64EncodedString:value options:0]; total+=bytes.length;
                if(!bytes.length || total>100*1024*1024) goto failed;
                // Decode only known raster formats, with bounded dimensions.
                static void *handle; static CGImageSourceRef (*openData)(CFDataRef,CFDictionaryRef); static dispatch_once_t once;
                dispatch_once(&once,^{ handle=dlopen("/System/Library/Frameworks/ImageIO.framework/ImageIO",RTLD_LAZY); openData=dlsym(handle,"CGImageSourceCreateWithData"); });
                CGImageSourceRef source=openData ? openData((__bridge CFDataRef)bytes,(__bridge CFDictionaryRef)@{@"kCGImageSourceShouldCache":@NO}) : nil;
                DPEaselImageFunctions api=DPEaselImageIO();
                NSString *type=source ? (__bridge NSString *)api.type(source) : nil;
                NSDictionary *props=source ? CFBridgingRelease(api.properties(source,0,nil)) : nil;
                double width=[props[@"PixelWidth"] doubleValue],height=[props[@"PixelHeight"] doubleValue];
                BOOL valid=[@[@"public.png",@"public.jpeg",@"com.compuserve.gif"] containsObject:type ?: @""] && width>0 && height>0 && width*height<=64000000 && api.count(source)<=1000;
                if(source) CFRelease(source); if(!valid) goto failed;
                assets[key]=bytes;
            }
            return @{@"document":envelope[@"document"],@"assets":assets};
        }
    }
failed: if(error) *error=DPEaselError(reason); return nil;
}
