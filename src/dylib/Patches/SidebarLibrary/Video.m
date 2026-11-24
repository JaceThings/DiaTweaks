#import "Library.h"
#import <AVFoundation/AVFoundation.h>
// Called only on the bounded thumbnail queue. A single local still, never playback.
NSImage *DPLibraryVideoStill(NSURL *url) {
    if (!url.isFileURL) return nil;
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:@{AVURLAssetPreferPreciseDurationAndTimingKey:@NO}];
    AVAssetImageGenerator *generator = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generator.maximumSize = CGSizeMake(420,420); generator.appliesPreferredTrackTransform = YES;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    __block NSImage *result;
    [generator generateCGImagesAsynchronouslyForTimes:@[[NSValue valueWithCMTime:CMTimeMake(1,2)]] completionHandler:^(CMTime requested,CGImageRef pixels,CMTime actual,AVAssetImageGeneratorResult status,NSError *error) {
        if (pixels && status == AVAssetImageGeneratorSucceeded) @synchronized(generator) {
            result = [[NSImage alloc] initWithCGImage:pixels size:NSZeroSize];
        }
        dispatch_semaphore_signal(done);
    }];
    if (dispatch_semaphore_wait(done,dispatch_time(DISPATCH_TIME_NOW,3*NSEC_PER_SEC))) [generator cancelAllCGImageGeneration];
    @synchronized(generator) { return result; }
}
