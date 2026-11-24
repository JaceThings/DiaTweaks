#import "Canvas.h"
static NSUserDefaults *DPShapeDefaults(void) {
    static NSUserDefaults *defaults; static dispatch_once_t once;
    dispatch_once(&once,^{ defaults=[[NSUserDefaults alloc] initWithSuiteName:NSProcessInfo.processInfo.environment[@"DIATWEAKS_DOMAIN"] ?: @"com.diapatches"]; });
    return defaults;
}
BOOL DPEaselShapeOutline(NSString *tool) {
    return [@[@"oval",@"rectangle"] containsObject:tool] && [DPShapeDefaults() boolForKey:[@"easelShapeOutline." stringByAppendingString:tool]];
}
void DPEaselRememberShapeOutline(NSString *tool,BOOL outline) {
    if([@[@"oval",@"rectangle"] containsObject:tool]) [DPShapeDefaults() setBool:outline forKey:[@"easelShapeOutline." stringByAppendingString:tool]];
}
