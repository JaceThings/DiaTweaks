#import "TextSizeButton.h"
#import "Canvas.h"
@implementation DPEaselTextSizeButton
- (void)mouseDown:(NSEvent *)event {
    DPEaselCanvas *canvas=self.canvas;
    [DPEaselHost finishEditingDocument:canvas.document]; [canvas endText];
    NSUndoManager *undo=canvas.document.undo;
    [undo beginUndoGrouping];
    @try { [super mouseDown:event]; }
    @finally { [undo endUndoGrouping]; }
}
@end
