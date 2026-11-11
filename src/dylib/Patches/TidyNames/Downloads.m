#import "Feedback.h"
#import "Names.h"
#import "DownloadBridge.h"

#define DPDiaDownloadBridge "_TtC3ADK36BrowserContextDownloadDelegateBridge"
#define DPDiaDownloadItem "ArcDownloadItem"

@interface NSObject (DPTidyDownloadMetadata)
- (NSString *)id;
- (NSString *)targetPath;
- (NSInteger)currentState;
@end

extern DPPatch DPTidyNames, DPTidyDownloads;
BOOL DPTidyLoadDownloadExtension(void);
void DPTidyUnregisterDownloadExtension(void);

@interface DPTidyDownloadRecord : NSObject
@property(copy) NSString *value;
@property(weak) NSWindow *window;
@property NSTimeInterval timestamp;
@end
@implementation DPTidyDownloadRecord @end

static NSMutableDictionary<NSString *, DPTidyDownloadRecord *> *DPActive, *DPCompleted, *DPAnnounced;

static BOOL DPTidyDownloadsEnabled(void) { return DPTidyNames.on && DPTidyDownloads.on; }

static void DPTidyRememberDownload(NSMutableDictionary *records, NSString *key, NSString *value, NSWindow *window) {
    NSTimeInterval now = NSProcessInfo.processInfo.systemUptime;
    for (NSString *oldKey in records.allKeys)
        if (now - [(DPTidyDownloadRecord *)records[oldKey] timestamp] > 60) [records removeObjectForKey:oldKey];
    if (records.count >= 128) [records removeObjectForKey:records.allKeys.firstObject];
    DPTidyDownloadRecord *record = [DPTidyDownloadRecord new];
    record.value = value;
    record.window = window;
    record.timestamp = now;
    records[key] = record;
}

static void DPTidyPresentFinishedDownload(DPTidyDownloadRecord *finished, NSString *original, NSTimeInterval deadline) {
    NSWindow *window = finished.window;
    if (!DPTidyDownloadsEnabled() || !window.isVisible) return;
    NSView *button = DPFindView(window.contentView, ^BOOL(NSView *view) {
        return DPIsKind(view, DPDiaDownloadsButton) && !view.hiddenOrHasHiddenAncestor && !NSIsEmptyRect(view.bounds);
    });
    if (button && DPTidyShowDownloadRename(button, original, finished.value)) return;

    // A small download may finish before Dia inserts its downloads button.
    if (NSProcessInfo.processInfo.systemUptime < deadline)
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            DPTidyPresentFinishedDownload(finished, original, deadline);
        });
}

static void DPTidyShowFinishedDownload(NSString *digest) {
    DPTidyDownloadRecord *finished = DPCompleted[digest], *announcement = DPAnnounced[digest];
    if (!finished || !announcement) return;
    [DPCompleted removeObjectForKey:digest];
    [DPAnnounced removeObjectForKey:digest];
    if (fabs(finished.timestamp - announcement.timestamp) > 10 ||
        [finished.value isEqualToString:announcement.value] || !finished.window) return;
    DPTidyPresentFinishedDownload(finished, announcement.value, NSProcessInfo.processInfo.systemUptime + 1.2);
}

static void DPDownloadUpdated(id self, SEL _cmd, id context, id item) {
    DPCallOriginal(DPDownloadUpdated, self, context, item);
    if (!DPTidyDownloadsEnabled() || !DPIsKind(item, DPDiaDownloadItem)) return;
    NSString *identifier = [item id];
    if (!identifier.length) return;
    NSInteger state = [item currentState];
    if (state < 2) {
        if (!DPActive[identifier]) DPTidyRememberDownload(DPActive, identifier, nil, NSApp.mainWindow);
        return;
    }
    NSWindow *window = DPActive[identifier].window ?: NSApp.mainWindow;
    [DPActive removeObjectForKey:identifier];
    NSString *path = [item targetPath];
    if (state != 2 || ![path hasPrefix:@"/"] || !window) return;
    NSString *digest = DPTidyDownloadPathDigest(path);
    DPTidyRememberDownload(DPCompleted, digest, path.lastPathComponent, window);
    DPTidyShowFinishedDownload(digest);
}

void DPInstallTidyDownloads(void) {
    if (!DPTidyDownloadsEnabled()) {
        DPTidyUnregisterDownloadExtension();
        return;
    }
    if (!DPTidyLoadDownloadExtension()) return;
    DPActive = [NSMutableDictionary new];
    DPCompleted = [NSMutableDictionary new];
    DPAnnounced = [NSMutableDictionary new];
    DPHook(DPDiaDownloadBridge, @selector(browserContext:onDownloadUpdated:), (IMP)DPDownloadUpdated);
    [NSDistributedNotificationCenter.defaultCenter addObserverForName:DPTidyDownloadFinished object:nil
        queue:NSOperationQueue.mainQueue usingBlock:^(NSNotification *note) {
            NSString *digest = note.object;
            NSString *original = note.userInfo[@"original"];
            if (!DPTidyDownloadsEnabled() || ![digest isKindOfClass:NSString.class] || digest.length != 64 ||
                ![original isKindOfClass:NSString.class] || original.length > 256 ||
                ![original isEqualToString:original.lastPathComponent] || !DPTidyDownloadNeedsRename(original)) return;
            DPTidyRememberDownload(DPAnnounced, digest, original, nil);
            DPTidyShowFinishedDownload(digest);
        }];
}
