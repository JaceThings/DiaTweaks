#import "Dust.h"
NSData *DPLibraryDustSamples(CGImageRef image,NSSize size,NSUInteger budget,CGFloat *step) {
    CGFloat spacing=MAX(1.5,sqrt(size.width*size.height/500000.));
    NSUInteger columns=MAX(1,floor(size.width/spacing)),rows=MAX(1,floor(size.height/spacing));
    NSMutableData *pixels=[NSMutableData dataWithLength:columns*rows*4];
    CGColorSpaceRef space=CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,columns,rows,8,columns*4,space,kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(space); if(!context) return NSData.data;
    CGContextSetInterpolationQuality(context,kCGInterpolationLow); CGContextDrawImage(context,CGRectMake(0,0,columns,rows),image); CGContextRelease(context);
    NSMutableData *samples=NSMutableData.new; const uint8_t *bytes=pixels.bytes;
    NSUInteger eligible=0; for(NSUInteger i=0;i<columns*rows;i++) if(bytes[i*4+3]>=4) eligible++;
    NSUInteger target=MIN(eligible,budget),accumulator=0;
    for(NSUInteger y=0;y<rows;y++) for(NSUInteger x=0;x<columns;x++) {
        const uint8_t *color=bytes+4*(y*columns+x); float alpha=color[3]/255.f;
        if(alpha<.015) continue;
        accumulator+=target; if(accumulator<eligible) continue; accumulator-=eligible;
        uint32_t hash=(uint32_t)(x*374761393u+y*668265263u); hash=(hash^(hash>>13))*1274126177u;
        DPLibraryParticle particle={ (x+.5f)*size.width/columns,(y+.5f)*size.height/rows,
            MIN(1,color[0]/255.f/alpha),MIN(1,color[1]/255.f/alpha),MIN(1,color[2]/255.f/alpha),alpha,(hash%10000)/10000.f };
        [samples appendBytes:&particle length:sizeof(particle)];
    }
    if(step) *step=MAX(size.width/columns,size.height/rows); return samples;
}
