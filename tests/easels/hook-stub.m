#import "StdPatch/StdPatch.h"

// Each fixture supplies its own original implementation without swizzling AppKit.
IMP DPPushOriginalIMP(id object, SEL selector, IMP replacement, DPHookFrame *frame) {
    return DPOriginalIMP(object, selector, replacement);
}
void DPPopOriginalIMP(DPHookFrame *frame) {}
