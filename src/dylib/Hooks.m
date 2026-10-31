#import "DiaPatches.h"

// Button hooks are added per class as buttons appear, so the count isn't fixed. Running out must stop here:
// a hook that silently didn't land leaves its callers asking DPOriginalIMP for an original it never stored.
typedef struct { Class cls; SEL sel; IMP imp; } DPOriginal;
static DPOriginal DPOriginals[256];
static int DPOriginalCount;

void DPHook(Class cls, SEL sel, IMP replacement) {
    Method method = cls ? class_getInstanceMethod(cls, sel) : NULL;
    if (!method || method_getImplementation(method) == replacement) return;
    if (DPOriginalCount == 256) abort();
    IMP original = method_getImplementation(method);
    if (!class_addMethod(cls, sel, replacement, method_getTypeEncoding(method))) method_setImplementation(method, replacement);
    DPOriginals[DPOriginalCount++] = (DPOriginal){cls, sel, original};
}

IMP DPOriginalIMP(id object, SEL sel) {
    for (Class c = object_getClass(object); c; c = class_getSuperclass(c))
        for (int i = 0; i < DPOriginalCount; i++)
            if (DPOriginals[i].cls == c && DPOriginals[i].sel == sel) return DPOriginals[i].imp;
    abort();
}
