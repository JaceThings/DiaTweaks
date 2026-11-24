#import <AppKit/AppKit.h>
NSRect DPEaselDragRect(NSPoint anchor,NSPoint end,BOOL square);
NSPoint DPEaselStraightEnd(NSPoint anchor,NSPoint end);
NSBezierPath *DPEaselArrow(NSPoint start,NSPoint end,CGFloat lineWidth);
NSBezierPath *DPEaselSmoothPath(NSArray<NSArray<NSNumber *> *> *points);
NSArray<NSArray<NSNumber *> *> *DPEaselTemplate(NSString *type,NSRect bounds);
NSDictionary *DPEaselRecognition(NSArray<NSArray<NSNumber *> *> *points);
NSString *DPEaselRecognize(NSArray<NSArray<NSNumber *> *> *points);
NSDictionary *DPEaselSnap(NSRect proposed,NSArray<NSValue *> *neighbors,NSSize canvas,BOOL bypass);
NSDictionary *DPEaselSnapWithin(NSRect proposed,NSArray<NSValue *> *neighbors,NSSize canvas,BOOL bypass,CGFloat radius);
