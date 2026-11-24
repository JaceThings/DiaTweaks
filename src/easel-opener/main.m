#import <AppKit/AppKit.h>
@interface DPEaselFileOpener : NSObject <NSApplicationDelegate>
@property NSArray<NSURL *> *pending;
@property NSTimer *timeout;
@end
@implementation DPEaselFileOpener
- (void)application:(NSApplication *)app openURLs:(NSArray<NSURL *> *)urls {
    NSMutableArray *valid=NSMutableArray.new;
    for(NSURL *url in urls) if(url.isFileURL && [url.pathExtension.lowercaseString isEqual:@"easel"]) [valid addObject:url];
    self.pending=valid;
    if(!valid.count) { [app terminate:nil]; return; }
    [NSDistributedNotificationCenter.defaultCenter addObserver:self selector:@selector(acknowledged:) name:@"com.diapatches.easel.imported" object:nil];
    NSWorkspaceOpenConfiguration *configuration=NSWorkspaceOpenConfiguration.configuration;
    [NSWorkspace.sharedWorkspace openApplicationAtURL:[NSURL fileURLWithPath:@"/Applications/Dia.app"] configuration:configuration completionHandler:^(NSRunningApplication *application,NSError *error){
        dispatch_async(dispatch_get_main_queue(),^{
            if(error) { NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t open Dia"; alert.informativeText=error.localizedDescription; [alert runModal]; [app terminate:nil]; return; }
            [self deliver];
            self.timeout=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(deliver) userInfo:nil repeats:YES];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW,30*NSEC_PER_SEC),dispatch_get_main_queue(),^{
                if(self.pending.count) { [self.timeout invalidate]; NSAlert *alert=NSAlert.new; alert.messageText=@"Enable Easels in DiaTweaks"; alert.informativeText=@"Enable Easels, then open the file again or import it from Library. The original file has not been changed."; [alert runModal]; [app terminate:nil]; }
            });
        });
    }];
}
- (void)deliver {
    for (NSURL *url in self.pending) {
        [NSDistributedNotificationCenter.defaultCenter postNotificationName:@"com.diapatches.easel.open" object:url.absoluteString userInfo:nil deliverImmediately:YES];
    }
}
- (void)acknowledged:(NSNotification *)note {
    self.pending=[self.pending filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSURL *url,id bindings){ return ![url.absoluteString isEqual:note.object]; }]];
    if(!self.pending.count) { [self.timeout invalidate]; [NSApp terminate:nil]; }
}
@end
int main(void) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; DPEaselFileOpener *delegate=DPEaselFileOpener.new; app.delegate=delegate; [app run]; } }
