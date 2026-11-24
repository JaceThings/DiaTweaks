#import "Easels.h"
#import <math.h>

static BOOL DPNumber(id number,double minimum,double maximum) {
    return [number isKindOfClass:NSNumber.class] && isfinite([number doubleValue]) &&
        [number doubleValue] >= minimum && [number doubleValue] <= maximum;
}
BOOL DPEaselValidSnapshot(NSDictionary *snapshot) {
    if (![snapshot isKindOfClass:NSDictionary.class] || ![NSJSONSerialization isValidJSONObject:snapshot] || ![snapshot[@"schema"] isEqual:@1] ||
        !DPEaselUUID(snapshot[@"id"]) || !DPNumber(snapshot[@"revision"],0,9007199254740991.0) ||
        !DPNumber(snapshot[@"created"],0,1e12) || !DPNumber(snapshot[@"modified"],0,1e12)) return NO;
    id profile=snapshot[@"profile"];
    if(profile && (![profile isKindOfClass:NSString.class] || ![profile length] || [profile length]>255 || ![[profile lastPathComponent] isEqual:profile] || [profile hasPrefix:@"."])) return NO;
    NSArray *size = snapshot[@"size"], *objects = snapshot[@"objects"];
    if (![size isKindOfClass:NSArray.class] || size.count != 2 || !DPNumber(size[0],320,16384) ||
        !DPNumber(size[1],320,16384) || ![objects isKindOfClass:NSArray.class] || objects.count > 10000) return NO;
    if(snapshot[@"titleModel"] && ![snapshot[@"titleModel"] isEqual:@2]) return NO;
    NSUInteger titleCount=0;
    NSSet *types = [NSSet setWithArray:@[@"text",@"image",@"oval",@"rectangle",@"arrow",@"pen",@"heart",@"line",@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"]];
    NSMutableSet *identifiers = NSMutableSet.new;
    for (NSDictionary *object in objects) {
        if (![object isKindOfClass:NSDictionary.class] || !DPEaselUUID(object[@"id"]) ||
            [identifiers containsObject:object[@"id"]] || ![types containsObject:object[@"type"]] ||
            !DPNumber(object[@"order"],0,1e12) || !DPNumber(object[@"z"],-1e12,1e12)) return NO;
        [identifiers addObject:object[@"id"]];
        if(object[@"isTitle"] && ![object[@"isTitle"] isKindOfClass:NSNumber.class]) return NO;
        if([object[@"isTitle"] boolValue] && (![object[@"type"] isEqual:@"text"] || ++titleCount>1)) return NO;
        NSArray *rect = object[@"rect"];
        if (![rect isKindOfClass:NSArray.class] || rect.count != 4) return NO;
        for (id number in rect) if (!DPNumber(number,-32768,32768)) return NO;
        if ([rect[2] doubleValue] < 1 || [rect[3] doubleValue] < 1) return NO;
        if ([object[@"type"] isEqual:@"text"] && (![object[@"text"] isKindOfClass:NSString.class] ||
            [object[@"text"] length] > 1000000 || !DPNumber(object[@"size"],8,240))) return NO;
        if ([object[@"type"] isEqual:@"image"] && !DPEaselUUID(object[@"asset"])) return NO;
        if (object[@"placeholder"] && ![object[@"placeholder"] isKindOfClass:NSNumber.class]) return NO;
        if (object[@"bold"] && ![object[@"bold"] isKindOfClass:NSNumber.class]) return NO;
        if (object[@"semanticInk"] && ![object[@"semanticInk"] isKindOfClass:NSNumber.class]) return NO;
        if (object[@"colorAppearance"] && ![@[@"light",@"dark"] containsObject:object[@"colorAppearance"]]) return NO;
        if (object[@"animated"] && ![object[@"animated"] isKindOfClass:NSNumber.class]) return NO;
        if (object[@"font"] && ![object[@"font"] isKindOfClass:NSString.class]) return NO;
        if (object[@"outline"] && ![object[@"outline"] isKindOfClass:NSNumber.class]) return NO;
        if (object[@"stroke"] && !DPNumber(object[@"stroke"],1,48)) return NO;
        NSArray *crop=object[@"crop"];
        if(crop) {
            if(![object[@"type"] isEqual:@"image"] || ![crop isKindOfClass:NSArray.class] || crop.count!=4) return NO;
            for(id value in crop) if(!DPNumber(value,0,1)) return NO;
            if([crop[2] doubleValue]<=0 || [crop[3] doubleValue]<=0 || [crop[0] doubleValue]+[crop[2] doubleValue]>1.000001 || [crop[1] doubleValue]+[crop[3] doubleValue]>1.000001) return NO;
        }
        NSArray *color=object[@"color"];
        if(color) {
            if(![color isKindOfClass:NSArray.class] || color.count!=4) return NO;
            for(id channel in color) if(!DPNumber(channel,0,1)) return NO;
        }
        if (object[@"alt"] && (![object[@"alt"] isKindOfClass:NSString.class] || [object[@"alt"] length]>10000)) return NO;
        NSArray *points = object[@"points"];
        if (points) {
            if (![points isKindOfClass:NSArray.class] || points.count>100000) return NO;
            for (NSArray *point in points) if (![point isKindOfClass:NSArray.class] || point.count!=2 ||
                !DPNumber(point[0],-32768,32768) || !DPNumber(point[1],-32768,32768)) return NO;
        }
        NSString *type=object[@"type"];
        if([type isEqual:@"arrow"] && points.count!=2) return NO;
        if([@[@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"] containsObject:type] && points.count<3) return NO;
        if(([type isEqual:@"pen"] || [type isEqual:@"line"]) && points.count<2) return NO;
    }
    return YES;
}
