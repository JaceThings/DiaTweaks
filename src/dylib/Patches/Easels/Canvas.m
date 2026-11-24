#import "Canvas.h"
#import "Patches/SidebarLibrary/MotionClock.h"
@implementation DPEaselCanvas
- (instancetype)initWithFrame:(NSRect)frame {
    if((self=[super initWithFrame:frame])) {
        _tool=@"select"; _selection=NSMutableSet.new; _images=NSCache.new; _images.totalCostLimit=24*1024*1024;
        _imageRequests=NSMutableSet.new; _failedImages=NSMutableSet.new; _staticAssets=NSMutableSet.new;
        _resizing=-1;
        _toolColors=NSMutableDictionary.new; _toolColorAppearances=NSMutableDictionary.new; _textStyle=@{@"font":@"sans",@"size":@24}; _lastDrawingTool=@"text";
        __weak DPEaselCanvas *weak=self;
        _changes=[NSNotificationCenter.defaultCenter addObserverForName:DPEaselChanged object:nil queue:nil usingBlock:^(NSNotification *note) {
            DPEaselCanvas *canvas=weak; if(!canvas || canvas.document!=note.object) return;
            [canvas.selection intersectSet:[NSSet setWithArray:[canvas.document.objects valueForKey:@"id"]]];
            canvas.needsDisplay=YES; if(canvas.selectionChanged) canvas.selectionChanged();
        }];
        [self registerForDraggedTypes:@[NSPasteboardTypeFileURL,NSPasteboardTypePNG,NSPasteboardTypeTIFF]];
    }
    return self;
}
- (void)dealloc { [_dwell invalidate]; [_textSave invalidate]; [_animationClock stop]; [_refinementClock stop]; [NSNotificationCenter.defaultCenter removeObserver:_changes]; }
- (BOOL)isFlipped { return YES; }
- (BOOL)isOpaque { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (BOOL)acceptsFirstMouse:(NSEvent *)event { return YES; }
- (BOOL)mouseDownCanMoveWindow { return NO; }
- (NSUndoManager *)undoManager { return self.document.undo; }
- (NSArray *)displayObjects { return self.previewObjects ?: self.document.objects; }
- (void)commit:(NSArray *)objects action:(NSString *)action {
    [DPEaselHost finishEditingDocument:self.document];
    BOOL conflict=NO; objects=DPEaselMergeGesture(self.initialObjects,objects,self.document.objects,&conflict);
    if(conflict) NSAccessibilityPostNotificationWithUserInfo(self,NSAccessibilityAnnouncementRequestedNotification,
        @{NSAccessibilityAnnouncementKey:@"This Easel changed in another window. Please try the gesture again.",NSAccessibilityPriorityKey:@(NSAccessibilityPriorityMedium)});
    [self.document replaceObjects:objects action:action];
    [DPEaselStore.shared save:self.document completion:^(NSError *error){ if(error) NSLog(@"Easel save failed: %@",error.localizedDescription); }];
    self.previewObjects=nil; self.needsDisplay=YES;
}
- (void)selectTool:(NSString *)tool {
    [self endText]; [self cancelGesture]; [self cancelImageImport]; self.toolCursor=nil; self.tool=tool; [self.selection removeAllObjects];
    if(![tool isEqual:@"select"] && ![tool isEqual:@"image"]) {
        self.lastDrawingTool=tool; if(self.toolColors[tool]) { self.color=self.toolColors[tool]; self.colorAppearance=self.toolColorAppearances[tool]; }
    }
    [self.window makeFirstResponder:self]; [self.window invalidateCursorRectsForView:self];
    if(self.selectionChanged) self.selectionChanged(); self.needsDisplay=YES;
}
- (void)cancelGesture {
    [self.refinementClock stop]; self.refinementClock=nil;
    if(self.duplicatingSelection && self.previewObjects) [self.selection setSet:self.dragSelection ?: NSSet.set];
    self.dragObjects=nil; self.dragSelection=nil; self.duplicatingSelection=NO; self.cropping=NO; self.cropEdges=0;
    [self.dwell invalidate]; self.dwell=nil; self.recognitionToken=nil; self.previewObjects=nil; self.draft=nil; self.samples=nil;
    self.initialObjects=nil; self.guides=nil; self.moving=NO; self.draggingSelection=NO; self.marquee=NO; self.resizing=-1; self.resizeGrabOffset=NSZeroPoint; self.needsDisplay=YES;
}
@end
