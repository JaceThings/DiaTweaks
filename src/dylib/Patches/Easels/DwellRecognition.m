#import "Canvas.h"
@implementation DPEaselCanvas (DwellRecognition)
- (void)refineHeldStroke {
    if(!self.draft || ![self.tool isEqual:@"pen"]) return;
    NSString *token=NSUUID.UUID.UUIDString,*identifier=self.draft[@"id"]; self.recognitionToken=token;
    NSArray *samples=self.samples.copy; __weak DPEaselCanvas *weak=self;
    static NSOperationQueue *queue; static dispatch_once_t once;
    dispatch_once(&once,^{ queue=NSOperationQueue.new; queue.maxConcurrentOperationCount=1; queue.qualityOfService=NSQualityOfServiceUtility; });
    [queue addOperationWithBlock:^{ @autoreleasepool {
        NSDictionary *match=DPEaselRecognition(samples);
        dispatch_async(dispatch_get_main_queue(),^{
            DPEaselCanvas *canvas=weak;
            if(!match || ![canvas.recognitionToken isEqual:token] || ![canvas.draft[@"id"] isEqual:identifier] || ![canvas.tool isEqual:@"pen"]) return;
            canvas.draft[@"type"]=match[@"type"]; canvas.draft[@"outline"]=@YES; canvas.draft[@"points"]=match[@"points"];
            canvas.draft[@"rect"]=DPEaselRectArray([match[@"rect"] rectValue]); [canvas animateRefinementFrom:samples];
        });
    }}];
}
@end
