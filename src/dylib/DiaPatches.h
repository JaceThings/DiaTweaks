#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

void DPHook(Class cls, SEL sel, IMP replacement);
IMP DPOriginalIMP(id object, SEL sel);

#define DPCallOriginal(type, object, sel, ...) ((type)DPOriginalIMP(object, sel))(object, sel, ##__VA_ARGS__)
