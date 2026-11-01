#import "Settings.h"
#import <AVFoundation/AVFoundation.h>

#ifndef DP_PREVIEWS
#define DP_PREVIEWS "https://raw.githubusercontent.com/wiki/JaceThings/DiaTweaks/previews/"
#endif

static NSNotificationName const DPTabLayoutMayHaveChanged = @"DPTabLayoutMayHaveChanged";

// Dia adds the sidebar's footer to a window with vertical tabs and takes it away with horizontal ones.
static void DPSidebarFooter_viewDidMoveToWindow(NSView *self, SEL _cmd) {
    DPCallOriginal(DPSidebarFooter_viewDidMoveToWindow, self);
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSNotificationCenter.defaultCenter postNotificationName:DPTabLayoutMayHaveChanged object:nil];
    });
}

void DPInstallPreviews(void) {
    DPHook(DPDiaSidebarFooter, @selector(viewDidMoveToWindow), (IMP)DPSidebarFooter_viewDidMoveToWindow);
}

@implementation DPPreviewView {
    NSString *_key, *_layout;
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

- (instancetype)initWithKey:(NSString *)key {
    if (!(self = [super initWithFrame:NSZeroRect])) return nil;
    _key = key;
    _placeholder = DPLabel(@"No preview yet", 12, NSFontWeightRegular, NSColor.tertiaryLabelColor);
    _placeholder.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:_placeholder];
    [_placeholder.centerXAnchor constraintEqualToAnchor:self.centerXAnchor].active = YES;
    [_placeholder.centerYAnchor constraintEqualToAnchor:self.centerYAnchor].active = YES;
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(load) name:DPTabLayoutMayHaveChanged object:nil];
    [self load];
    return self;
}

// Previews are named for the tab layout they were recorded in. The one matching Dia's layout wins, then the other.
- (void)load {
    NSString *layout = DPTabLayout(), *other = [layout isEqual:@"vertical"] ? @"horizontal" : @"vertical";
    if ([layout isEqual:_layout]) return;
    _layout = layout;
    NSMutableArray<NSString *> *names = [NSMutableArray new];
    for (NSString *prefix in @[layout, other])
        for (NSString *ext in @[@"mp4", @"png"]) [names addObject:[NSString stringWithFormat:@"%@-%@.%@", prefix, _key, ext]];
    _names = names;
    for (NSString *name in _names)
        if ([DPCachedPreview(name) checkResourceIsReachableAndReturnError:nil]) {
            [self show:DPCachedPreview(name)];
            break;
        }
    [self fetch:_names];
}

- (void)fetch:(NSArray<NSString *> *)names {
    if (!names.count) return [self show:nil];
    NSURL *cached = DPCachedPreview(names[0]);
    NSURL *url = [NSURL URLWithString:[@DP_PREVIEWS stringByAppendingString:names[0]]];
    __weak DPPreviewView *weakSelf = self;
    NSArray<NSString *> *current = _names;
    [[NSURLSession.sharedSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger status = [(NSHTTPURLResponse *)response statusCode];
        dispatch_async(dispatch_get_main_queue(), ^{
            DPPreviewView *view = weakSelf;
            // The layout changed while this was loading, and a fetch for the new one has started.
            if (!view || view->_names != current) return;
            if (error || (status != 200 && status != 404)) return;
            if (status == 404) {
                [NSFileManager.defaultManager removeItemAtURL:cached error:nil];
                return [view fetch:[names subarrayWithRange:NSMakeRange(1, names.count - 1)]];
            }
            if ([[NSData dataWithContentsOfURL:cached] isEqualToData:data]) return;
            [data writeToURL:cached atomically:YES];
            [view show:cached];
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
