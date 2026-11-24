#import "Patches/SidebarLibrary/Dust.h"
int main(void) { @autoreleasepool {
 unsigned char pixels[8*8*4]={0};for(int y=0;y<8;y++)for(int x=0;x<8;x++){int i=(y*8+x)*4;pixels[i+(y<4?0:2)]=255;pixels[i+3]=255;}
 CFDataRef data=CFDataCreate(NULL,pixels,sizeof(pixels));CGDataProviderRef provider=CGDataProviderCreateWithCFData(data);CGColorSpaceRef color=CGColorSpaceCreateDeviceRGB();
 CGImageRef image=CGImageCreate(8,8,8,32,32,color,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,provider,NULL,NO,kCGRenderingIntentDefault);
 CGFloat step;NSData *samples=DPLibraryDustSamples(image,NSMakeSize(8,8),100,&step);const DPLibraryParticle *p=samples.bytes;NSUInteger n=samples.length/sizeof(*p);
 NSCAssert(p[0].r>.9 && p[0].b<.1 && p[n-1].b>.9 && p[n-1].r<.1,@"dust retains the snapshot’s vertical color orientation");
 printf("top red=%.1f blue=%.1f bottom red=%.1f blue=%.1f count=%lu\n",p[0].r,p[0].b,p[n-1].r,p[n-1].b,n);
 CGImageRelease(image);CGColorSpaceRelease(color);CGDataProviderRelease(provider);CFRelease(data);
} }
