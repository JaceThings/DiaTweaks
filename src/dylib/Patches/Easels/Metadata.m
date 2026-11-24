#import "HostInternal.h"
static NSString *DPEaselPageColor(NSView *view) {
    __block NSString *value=nil;
    [view.effectiveAppearance performAsCurrentDrawingAppearance:^{
        NSColor *color=[NSColor.textBackgroundColor colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
        value=[NSString stringWithFormat:@"#%02x%02x%02x",(int)round(color.redComponent*255),(int)round(color.greenComponent*255),(int)round(color.blueComponent*255)];
    }]; return value;
}
void DPEaselPublishTitle(DPEaselAttachment *attachment) {
    if(!attachment.document || attachment.document.deleted || !attachment.pane) return;
    NSString *title=DPEaselDisplayTitle(attachment.document.title);
    NSString *color=DPEaselPageColor(attachment.pane);
    if([title isEqual:attachment.publishedTitle] && [color isEqual:attachment.publishedAppearance]) return;
    [attachment.titleDelay invalidate]; __weak DPEaselAttachment *weak=attachment;
    attachment.titleDelay=[NSTimer timerWithTimeInterval:.25 repeats:NO block:^(NSTimer *timer){
        DPEaselAttachment *owner=weak; owner.titleDelay=nil;
        if(!DPEasels.on || !owner.pane || owner.document.deleted) return;
        NSString *identifier=[DPEaselStore.shared identifierForURL:DPEaselRead(owner.contents,@"url")];
        if(![identifier isEqual:owner.document.identifier]) return;
        NSString *current=DPEaselDisplayTitle(owner.document.title);
        NSString *background=DPEaselPageColor(owner.pane);
        BOOL dark=[[owner.pane.effectiveAppearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua];
        NSData *data=[NSJSONSerialization dataWithJSONObject:@[current,background,dark ? @"dark" : @"light"] options:0 error:nil];
        NSString *json=[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        SEL execute=@selector(executeJavascript:completion:);
        if(![owner.contents respondsToSelector:execute]) return;
        NSString *script=[NSString stringWithFormat:@"(()=>{const v=%@;document.title=v[0];document.documentElement.style.colorScheme=v[2];document.documentElement.style.backgroundColor=v[1];document.body.style.backgroundColor=v[1];let m=document.querySelector('meta[name=theme-color]');if(!m){m=document.createElement('meta');m.name='theme-color';document.head.append(m)}m.content=v[1]})()",json];
        if(!owner.publishedTitle) {
            [owner.contents willChangeValueForKey:@"favicon"];
            [owner.contents didChangeValueForKey:@"favicon"];
        }
        owner.publishedTitle=current; owner.publishedAppearance=background;
        ((void (*)(id,SEL,id,id))objc_msgSend)(owner.contents,execute,script,^(NSString *result,BOOL success){});
    }];
    [NSRunLoop.mainRunLoop addTimer:attachment.titleDelay forMode:NSRunLoopCommonModes];
}
static id DPTitle(id self,SEL _cmd) {
    NSString *title=DPEaselMetadataTitle(self);
    if(title) return title;
    return DPCallOriginal(DPTitle,self);
}
static id DPFavicon(id self,SEL _cmd) {
    if(DPEaselMetadataTitle(self))
        return [NSImage imageWithSystemSymbolName:@"pencil.and.outline" accessibilityDescription:@"Easel"];
    return DPCallOriginal(DPFavicon,self);
}
void DPEaselInstallMetadataHooks(void) {
    DPHook(DPDiaWebContents,@selector(title),(IMP)DPTitle);
    DPHook(DPDiaWebContents,@selector(favicon),(IMP)DPFavicon);
}
