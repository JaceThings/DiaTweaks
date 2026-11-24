#import "Canvas.h"
@implementation DPEaselDocument (Rename)
- (void)rename:(NSString *)name {
    name=[name stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if(!name.length || name.length>1000000 || self.deleted) return;
    NSMutableArray *objects=[self.objects mutableCopy]; BOOL found=NO;
    for(NSUInteger i=0;i<objects.count;i++) if([objects[i][@"isTitle"] boolValue]) {
        NSMutableDictionary *heading=[objects[i] mutableCopy];
        NSArray *lines=[heading[@"text"] componentsSeparatedByString:@"\n"];
        NSMutableArray *replacement=[lines mutableCopy]; if(!replacement.count) [replacement addObject:name]; else replacement[0]=name;
        heading[@"text"]=[replacement componentsJoinedByString:@"\n"]; heading[@"placeholder"]=@NO; objects[i]=DPEaselGrowTitle(heading); found=YES; break;
    }
    if(!found) {
        NSUInteger order=0; for(NSDictionary *object in objects) order=MAX(order,[object[@"order"] unsignedIntegerValue]+1);
        NSMutableDictionary *heading=[DPEaselText(name,NSMakeRect(MAX(24,(self.canvasSize.width-400)/2),32,MIN(400,self.canvasSize.width-48),88),order,YES) mutableCopy];
        heading[@"placeholder"]=@NO; [objects addObject:DPEaselGrowTitle(heading)];
    }
    [self replaceObjects:objects action:@"Rename Easel"];
}
@end
