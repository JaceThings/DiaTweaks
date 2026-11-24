#import "Library.h"
@interface DPLibraryDownloadProgress : NSView
@property double progress;
@property BOOL paused,determinate;
@end
@implementation DPLibraryDownloadProgress
- (NSView *)hitTest:(NSPoint)point { return nil; }
- (BOOL)isAccessibilityElement { return YES; }
- (NSString *)accessibilityRole { return NSAccessibilityProgressIndicatorRole; }
- (NSString *)accessibilityLabel { return self.paused ? @"Download paused" : @"Download progress"; }
- (id)accessibilityValue { return self.determinate ? @(self.progress) : nil; }
- (id)accessibilityMinValue { return @0; }
- (id)accessibilityMaxValue { return @1; }
- (void)drawRect:(NSRect)dirty {
    NSRect ring=NSInsetRect(self.bounds,4,4);
    [[NSColor.labelColor colorWithAlphaComponent:.13] setStroke];
    NSBezierPath *track=[NSBezierPath bezierPathWithOvalInRect:ring]; track.lineWidth=2.5; [track stroke];
    NSColor *ink=self.paused ? NSColor.secondaryLabelColor : DPLibraryAccentColor(self.window);
    [ink setStroke];
    if(self.determinate && self.progress>0) {
        NSBezierPath *arc=NSBezierPath.bezierPath; arc.lineWidth=2.5; arc.lineCapStyle=NSLineCapStyleRound;
        [arc appendBezierPathWithArcWithCenter:NSMakePoint(NSMidX(ring),NSMidY(ring)) radius:NSWidth(ring)/2 startAngle:90 endAngle:90-360*self.progress clockwise:YES]; [arc stroke];
    }
    NSString *symbol=self.paused ? @"pause.fill" : @"arrow.down";
    NSImage *image=[[NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil] imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithPaletteColors:@[ink]]];
    [image drawInRect:NSInsetRect(self.bounds,12,12) fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1];
}
@end
void DPLibraryUpdateDownloadProgress(NSTableCellView *cell,DPLibraryFile *file) {
    DPLibraryDownloadProgress *indicator=nil;
    for(NSView *view in cell.subviews) if([view isKindOfClass:DPLibraryDownloadProgress.class]) indicator=(id)view;
    BOOL active=!file.archived && file.state==1;
    if(active && !indicator) { indicator=[[DPLibraryDownloadProgress alloc] initWithFrame:cell.imageView.frame]; [cell addSubview:indicator]; }
    indicator.hidden=!active; cell.imageView.hidden=active;
    if(active) {
        indicator.frame=cell.imageView.frame; indicator.determinate=file.total>0;
        indicator.progress=file.total>0 ? MAX(0,MIN(1,(double)file.completed/file.total)) : 0;
        indicator.paused=file.paused; indicator.needsDisplay=YES;
        indicator.toolTip=DPLibraryFileDetail(file);
    }
}
