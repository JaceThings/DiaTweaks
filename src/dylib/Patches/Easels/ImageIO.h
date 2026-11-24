#import <ImageIO/ImageIO.h>
#import <dlfcn.h>
// Match Library's runtime loading: no new linked dependency or image library.
typedef struct {
    CGImageSourceRef (*open)(CFURLRef,CFDictionaryRef);
    CFStringRef (*type)(CGImageSourceRef);
    CFDictionaryRef (*properties)(CGImageSourceRef,size_t,CFDictionaryRef);
    CGImageRef (*thumbnail)(CGImageSourceRef,size_t,CFDictionaryRef);
    size_t (*count)(CGImageSourceRef);
} DPEaselImageFunctions;
static inline DPEaselImageFunctions DPEaselImageIO(void) {
    static DPEaselImageFunctions api; static dispatch_once_t once;
    dispatch_once(&once,^{
        void *handle=dlopen("/System/Library/Frameworks/ImageIO.framework/ImageIO",RTLD_LAZY);
        api.open=dlsym(handle,"CGImageSourceCreateWithURL"); api.type=dlsym(handle,"CGImageSourceGetType");
        api.properties=dlsym(handle,"CGImageSourceCopyPropertiesAtIndex");
        api.thumbnail=dlsym(handle,"CGImageSourceCreateThumbnailAtIndex");
        api.count=dlsym(handle,"CGImageSourceGetCount");
    });
    return api;
}
