#import "Patches/Easels/Animation.h"
#import "Patches/Easels/ImageIO.h"
#import <stdio.h>
static void waitUntil(BOOL (^done)(void)) {
    NSDate *limit=[NSDate dateWithTimeIntervalSinceNow:10];
    while(!done() && limit.timeIntervalSinceNow>0) [NSRunLoop.mainRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:.01]];
    NSCAssert(done(),@"frame decode completes");
}
int main(void) { @autoreleasepool {
    NSURL *url=[NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[NSUUID.UUID.UUIDString stringByAppendingPathExtension:@"gif"]]];
    void *imageIO=dlopen("/System/Library/Frameworks/ImageIO.framework/ImageIO",RTLD_LAZY);
    CGImageDestinationRef (*create)(CFURLRef,CFStringRef,size_t,CFDictionaryRef)=dlsym(imageIO,"CGImageDestinationCreateWithURL");
    void (*add)(CGImageDestinationRef,CGImageRef,CFDictionaryRef)=dlsym(imageIO,"CGImageDestinationAddImage");
    bool (*finish)(CGImageDestinationRef)=dlsym(imageIO,"CGImageDestinationFinalize");
    NSCAssert(create && add && finish,@"native GIF writer available");
    CGImageDestinationRef destination=create((__bridge CFURLRef)url,CFSTR("com.compuserve.gif"),2,NULL);
    for(NSUInteger i=0;i<2;i++) {
        NSDictionary *properties=@{@"{GIF}":@{@"DelayTime":i ? @.12 : @.06}};
        CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
        CGContextRef context=CGBitmapContextCreate(NULL,2,2,8,8,space,(CGBitmapInfo)kCGImageAlphaPremultipliedLast);
        CGContextSetRGBFillColor(context,i ? 0 : 1,i ? 1 : 0,0,1); CGContextFillRect(context,CGRectMake(0,0,2,2));
        CGImageRef pixels=CGBitmapContextCreateImage(context);
        add(destination,pixels,(__bridge CFDictionaryRef)properties);
        CGImageRelease(pixels); CGContextRelease(context); CGColorSpaceRelease(space);
    }
    NSCAssert(finish(destination),@"two-frame GIF fixture saved"); CFRelease(destination);
    DPEaselFrameSource *source=DPEaselFrameSource.new; source.url=url;
    for(NSUInteger frame=0;frame<2;frame++) {
        __block BOOL done=NO;
        BOOL queued=[source request:frame completion:^(NSImage *image,NSTimeInterval delay,NSUInteger count){
            NSCAssert(NSThread.isMainThread && image && count==2 && delay>=.04 && delay<=.15,@"native frame metadata and timing preserved");
            NSBitmapImageRep *bitmap=[NSBitmapImageRep imageRepWithData:image.TIFFRepresentation];
            NSColor *color=[[bitmap colorAtX:0 y:0] colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
            NSCAssert(frame ? color.greenComponent>color.redComponent : color.redComponent>color.greenComponent,@"requested GIF frames actually differ"); done=YES;
        }];
        NSCAssert(queued,@"bounded queue accepts unsaturated playback"); waitUntil(^BOOL { return done; });
    }
    [NSFileManager.defaultManager removeItemAtURL:url error:nil];
    puts("PASS: native two-frame GIF decoding, distinct frame pixels, preserved frame delays and main-thread delivery");
} }
