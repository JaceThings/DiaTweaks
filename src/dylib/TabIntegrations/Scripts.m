#import "TabIntegrations.h"
#import <mach-o/getsect.h>
extern const struct mach_header_64 __dso_handle;

static NSDictionary *DPTabIntegrationScripts(void) {
    static NSDictionary *scripts;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        unsigned long size = 0;
        const void *bytes = getsectiondata(&__dso_handle, "__TEXT", "__tab_scripts", &size);
        if (!bytes || !size) return;
        NSData *data = [NSData dataWithBytes:bytes length:size];
        id value = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if ([value isKindOfClass:NSDictionary.class]) scripts = value;
    });
    return scripts;
}

NSString *DPTabIntegrationScript(NSString *key) {
    if (![key isKindOfClass:NSString.class] || !key.length) return nil;
    id script = DPTabIntegrationScripts()[key];
    return [script isKindOfClass:NSString.class] && [script length] ? script : nil;
}
