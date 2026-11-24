#import "Canvas.h"
NSRect DPEaselObjectRect(NSDictionary *object) {
    NSArray *r=object[@"rect"];
    return NSMakeRect([r[0] doubleValue],[r[1] doubleValue],[r[2] doubleValue],[r[3] doubleValue]);
}
NSArray *DPEaselRectArray(NSRect r) { return @[@(r.origin.x),@(r.origin.y),@(r.size.width),@(r.size.height)]; }
NSFont *DPEaselFont(NSDictionary *object) {
    CGFloat size=MAX(8,MIN(240,[object[@"size"] doubleValue]));
    NSString *family=object[@"font"];
    NSFont *font=[NSFont systemFontOfSize:size weight:[object[@"bold"] boolValue] ? NSFontWeightBold : NSFontWeightRegular];
    if([family isEqual:@"serif"] || [family isEqual:@"rounded"] || [family isEqual:@"mono"]) {
        NSFontDescriptorSystemDesign design=[family isEqual:@"serif"] ? NSFontDescriptorSystemDesignSerif :
            [family isEqual:@"mono"] ? NSFontDescriptorSystemDesignMonospaced : NSFontDescriptorSystemDesignRounded;
        font=[NSFont fontWithDescriptor:[font.fontDescriptor fontDescriptorWithDesign:design] size:size] ?: font;
    } else if([family isEqual:@"script"]) font=[NSFont fontWithName:@"SnellRoundhand" size:size] ?: font;
    return font;
}
NSDictionary *DPEaselGrowTitle(NSDictionary *object) {
    if(![object[@"isTitle"] boolValue]) return object;
    NSRect frame=DPEaselObjectRect(object);
    NSRect measured=[object[@"text"] boundingRectWithSize:NSMakeSize(MAX(1,frame.size.width-8),CGFLOAT_MAX)
        options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:@{NSFontAttributeName:DPEaselFont(object)}];
    CGFloat height=MIN(32768,ceil(measured.size.height)+12);
    if(height<=frame.size.height) return object;
    frame.size.height=height; NSMutableDictionary *grown=[object mutableCopy]; grown[@"rect"]=DPEaselRectArray(frame); return grown;
}
NSString *DPEaselColorAppearance(NSAppearance *appearance) {
    return [[appearance bestMatchFromAppearancesWithNames:@[NSAppearanceNameAqua,NSAppearanceNameDarkAqua]] isEqual:NSAppearanceNameDarkAqua] ? @"dark" : @"light";
}
NSColor *DPEaselObjectColor(NSDictionary *object) {
    if([object[@"semanticInk"] boolValue]) return NSColor.labelColor;
    NSArray *color=object[@"color"];
    if(color.count!=4) return NSColor.labelColor;
    BOOL black=[color[0] doubleValue]==0 && [color[1] doubleValue]==0 && [color[2] doubleValue]==0;
    BOOL white=[color[0] doubleValue]==1 && [color[1] doubleValue]==1 && [color[2] doubleValue]==1;
    if(black || white) {
        NSString *origin=object[@"colorAppearance"];
        if(!origin.length) return [NSColor.labelColor colorWithAlphaComponent:[color[3] doubleValue]];
        CGFloat alpha=[color[3] doubleValue];
        return [NSColor colorWithName:nil dynamicProvider:^NSColor *(NSAppearance *appearance) {
            BOOL inverted=![origin isEqual:DPEaselColorAppearance(appearance)];
            return [(white!=inverted ? NSColor.whiteColor : NSColor.blackColor) colorWithAlphaComponent:alpha];
        }];
    }
    return [NSColor colorWithSRGBRed:[color[0] doubleValue] green:[color[1] doubleValue] blue:[color[2] doubleValue] alpha:[color[3] doubleValue]];
}

BOOL DPEaselObjectCanColor(NSDictionary *object) {
    return [@[@"text",@"oval",@"rectangle",@"arrow",@"pen",@"line",@"heart",@"triangle",@"diamond",@"star",@"pentagon",@"hexagon"] containsObject:object[@"type"] ?: @""];
}
