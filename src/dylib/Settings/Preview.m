#import "Settings.h"
#import <AVFoundation/AVFoundation.h>

#ifndef DP_PREVIEWS
#define DP_PREVIEWS "https://raw.githubusercontent.com/wiki/JaceThings/DiaTweaks/previews/"
#endif

@implementation DPPreviewView {
    NSArray<NSString *> *_names;
    CALayer *_media;
    AVPlayerLooper *_looper;
    NSTextField *_placeholder;
}

static NSURL *DPCachedPreview(NSString *name) {
    NSURL *caches = [NSFileManager.defaultManager URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask].firstObject;
    NSURL *dir = [caches URLByAppendingPathComponent:@"DiaPatches/previews" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:dir withIntermediateDirectories:YES attributes:nil error:nil];
    return [dir URLByAppendingPathComponent:name];
}

// Previews are named for the tab layout they were recorded in. The one matching Dia's layout wins, then the other.
- (instancetype)initWithKey:(NSString *)key {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    NSString *layout = DPTabLayout(), *other = [layout isEqual:@"vertical"] ? @"horizontal" : @"vertical";
    NSMutableArray<NSString *> *names = [NSMutableArray new];
    for (NSString *prefix in @[layout, other])
        for (NSString *ext in @[@"mp4", @"png"]) [names addObject:[NSString stringWithFormat:@"%@-%@.%@", prefix, key, ext]];
    _names = names;
    _placeholder = DPLabel(@"No preview yet", 12, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    _placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_placeholder];
    [_placeholder.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
    [_placeholder.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    for (NSString *name in _names)
        if ([DPCachedPreview(name) checkResourceIsReachableAndReturnError:nil]) {
            [self show:DPCachedPreview(name)];
            break;
        }
    [self fetch:_names];
    return self;
}

- (void)fetch:(NSArray<NSString *> *)names {
    if (!names.count) return [self show:nil];
    NSURL *cached = DPCachedPreview(names[0]);
    NSURL *url = [NSURL URLWithString:[@DP_PREVIEWS stringByAppendingString:names[0]]];
    __weak DPPreviewView *weakSelf = self;
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || (status != 200 && status != 404)) return;
            if (status == 404) {
                [NSFileManager.defaultManager removeItemAtURL:cached error:nil];
                return [weakSelf fetch:[names subarrayWithRange:NSMakeRange(1, names.count - 1)]];
            }
            if ([[NSData dataWithContentsOfURL:cached] isEqualToData:data]) return;
            [data writeToURL:cached atomically:YES];
            [weakSelf show:cached];
        });
    }] resume];
}

- (void)show:(NSURL *)file {
    [_media removeFromSuperlayer];
    _media = nil;
    _looper = nil;
    _placeholder.hidden = file != nil;
    if (!file) return;
    if ([file.pathExtension isEqualToString:@"mp4"]) {
        AVQueuePlayer *player = [AVQueuePlayer new];
        player.muted = YES;
        _looper = [AVPlayerLooper playerLooperWithPlayer:player templateItem:[AVPlayerItem playerItemWithURL:file]];
        AVPlayerLayer *layer = [AVPlayerLayer playerLayerWithPlayer:player];
        layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        _media = layer;
        [player play];
    } else {
        _media = [CALayer layer];
        _media.contents = [[NSImage alloc] initWithContentsOfURL:file];
        _media.contentsGravity = kCAGravityResizeAspectFill;
    }
    _media.frame = self.bounds;
    [self.layer addSublayer:_media];
}

- (void)layout {
    [super layout];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _media.frame = self.bounds;
    [CATransaction commit];
}
@end
