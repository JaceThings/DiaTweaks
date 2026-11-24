#import "Easels.h"
#import "Geometry.h"
#import "Assets.h"
void DPEaselStyleColorWell(NSVisualEffectView *view);
BOOL DPEaselShapeOutline(NSString *tool);
void DPEaselRememberShapeOutline(NSString *tool,BOOL outline);
@class DPLibraryMotionClock,DPEaselFrameSource;
NSRect DPEaselObjectRect(NSDictionary *object);
NSArray *DPEaselRectArray(NSRect rect);
NSFont *DPEaselFont(NSDictionary *object);
NSDictionary *DPEaselGrowTitle(NSDictionary *object);
NSColor *DPEaselObjectColor(NSDictionary *object);
NSString *DPEaselColorAppearance(NSAppearance *appearance);
BOOL DPEaselObjectCanColor(NSDictionary *object);
NSColor *DPEaselAccent(NSView *view);
NSDictionary *DPEaselTransformObject(NSDictionary *object,NSRect frame);
CGFloat DPEaselScreenUnit(NSView *view);
NSArray<NSValue *> *DPEaselSelectionHandles(NSDictionary *object);
NSUInteger DPEaselCropEdges(NSRect rect,NSPoint point,CGFloat tolerance);
NSCursor *DPEaselCropCursor(NSUInteger edges);
NSDictionary *DPEaselCropImage(NSDictionary *object,NSPoint point,NSUInteger edges,NSPoint offset,NSRect canvas);
NSRect DPEaselImageSourceRect(NSDictionary *object,NSImage *image);
NSArray<NSValue *> *DPEaselVisualHandles(NSDictionary *object,CGFloat unit);
NSArray<NSDictionary *> *DPEaselMergeGesture(NSArray<NSDictionary *> *base,NSArray<NSDictionary *> *edited,NSArray<NSDictionary *> *current,BOOL *conflict);
@interface DPEaselCanvas : NSView <NSTextViewDelegate>
@property DPEaselDocument *document;
@property NSString *tool;
@property NSMutableSet<NSString *> *selection;
@property NSArray<NSDictionary *> *previewObjects, *initialObjects, *guides;
@property NSArray<NSDictionary *> *hitObjects,*hitOrder,*dragObjects;
@property NSSet *dragSelection;
@property BOOL duplicatingSelection,cropping;
@property NSUInteger cropEdges;
@property NSEventModifierFlags pointerModifiers;
@property NSMutableDictionary *draft;
@property NSMutableArray *samples;
@property NSArray<NSNumber *> *color;
@property NSMutableDictionary<NSString *,NSArray *> *toolColors;
@property NSString *colorAppearance;
@property NSMutableDictionary<NSString *,NSString *> *toolColorAppearances;
@property NSDictionary *textStyle;
@property NSString *lastDrawingTool;
@property NSCache<NSString *,NSImage *> *images;
@property NSMutableSet<NSString *> *imageRequests;
@property NSMutableSet<NSString *> *failedImages;
@property NSPoint origin;
@property NSPoint resizeGrabOffset;
@property NSRect selectionBox;
@property BOOL moving, marquee, draggingSelection;
@property NSInteger resizing;
@property NSTimer *dwell;
@property NSString *recognitionToken;
@property NSTimer *textSave;
@property id changes;
@property(copy) void (^selectionChanged)(void);
@property NSTextView *textEditor;
@property NSString *textObjectID;
@property NSDictionary *originalText;
@property NSString *pendingAsset;
@property BOOL pendingAssetCommitted;
@property NSUInteger importGeneration;
@property NSSize pendingSize;
@property NSPoint pendingPoint;
@property NSTrackingArea *tracking;
@property NSCursor *toolCursor;
@property NSColor *cursorAccent;
@property NSString *cursorTool;
@property NSMutableDictionary *accessibleObjects;
@property DPLibraryMotionClock *animationClock,*refinementClock;
@property NSMutableDictionary<NSString *,DPEaselFrameSource *> *players;
@property NSMutableSet<NSString *> *staticAssets;
@property NSUInteger animationCursor;
- (NSArray<NSDictionary *> *)displayObjects;
- (void)commit:(NSArray<NSDictionary *> *)objects action:(NSString *)action;
- (void)selectTool:(NSString *)tool;
- (void)cancelGesture;
@end
@interface DPEaselCanvas (Cursors)
- (NSCursor *)drawingCursor;
@end
@interface DPEaselCanvas (InteractionCursors)
- (NSCursor *)interactionCursorAtPoint:(NSPoint)point;
- (NSCursor *)interactionCursorForEvent:(NSEvent *)event;
@end
@interface DPEaselCanvas (Drawing)
- (void)drawObjects:(NSArray *)objects inRect:(NSRect)dirty selection:(BOOL)selection;
@end
@interface DPEaselCanvas (ImportCancellation)
- (void)cancelImageImport;
@end
@interface DPEaselCanvas (Editing)
- (BOOL)handleSelectionKey:(NSEvent *)event;
- (NSDictionary *)objectAtPoint:(NSPoint)point;
- (void)placeImage:(NSString *)asset size:(NSSize)size atPoint:(NSPoint)point;
- (void)beginText:(NSDictionary *)object;
- (void)endText;
- (void)fitText:(NSDictionary *)object;
- (void)delete:(id)sender;
- (void)duplicate:(id)sender;
- (void)bringToFront:(id)sender;
- (void)sendToBack:(id)sender;
- (void)copy:(id)sender;
- (void)paste:(id)sender;
- (BOOL)pasteImageFromPasteboard:(NSPasteboard *)pasteboard atPoint:(NSPoint)point;
- (void)cut:(id)sender;
- (void)selectAll:(id)sender;
- (void)editAltText:(id)sender;
- (void)requestImage:(NSDictionary *)object;
- (void)reportImportError:(NSError *)error;
- (void)updatePenDwell;
- (void)refineHeldStroke;
- (void)animateRefinementFrom:(NSArray *)points;
- (void)beginDuplicateDrag;
- (void)resetImageCrop:(id)sender;
- (void)updateSelectionDrag:(NSPoint)point modifiers:(NSEventModifierFlags)modifiers;
- (NSDictionary *)resizeObject:(NSDictionary *)object toPoint:(NSPoint)point modifiers:(NSEventModifierFlags)modifiers neighbors:(NSArray<NSValue *> *)neighbors;
- (void)animateVisibleImages;
- (void)stopImageAnimations;
@end
@interface DPEaselEditorSurface : NSView
@property DPEaselCanvas *canvas;
@property NSScrollView *scroll;
@property NSVisualEffectView *toolbar,*colorWell,*exportWell;
@property NSButton *exportButton;
@property NSPopover *exportPopover;
@property id sharingSession;
@property NSButton *colorButton;
@property BOOL paletteEditsSelection;
@property NSMutableArray<NSButton *> *buttons;
@property NSView *contextTools;
@property NSVisualEffectView *objectColorWell;
@property NSButton *objectColorButton;
@property NSVisualEffectView *shapeOptions;
@property NSString *shapeOptionsContext;
@property NSTimer *shapeOptionsDelay;
@property NSPopover *palette;
@property NSString *contextSignature;
@property id scrollObserver;
@end
@interface DPEaselEditorSurface (SlideScaling)
- (void)fitSlideToViewport;
@end
@interface DPEaselEditorSurface (Tools)
- (void)refreshTools;
- (void)chooseTool:(NSButton *)button;
- (void)chooseImage:(id)sender;
@end
@interface DPEaselEditorSurface (ImageImport)
- (void)completeImageImport:(NSString *)asset size:(NSSize)size error:(NSError *)error document:(DPEaselDocument *)document generation:(NSUInteger)generation;
@end
@interface DPEaselEditorSurface (TextControls)
- (void)updateContextTools;
- (void)formatText:(NSButton *)button;
@end
@interface DPEaselEditorSurface (ObjectColor)
- (void)updateObjectColorControl;
@end
@interface DPEaselEditorSurface (ShapeOptions)
- (void)updateShapeOptions;
- (void)hideShapeOptions;
- (void)chooseShapeStyle:(NSButton *)sender;
@end
@interface DPEaselEditorSurface (Palette)
- (void)showPalette:(NSButton *)button;
- (void)selectColor:(NSButton *)button;
@end

@interface DPEaselEditorSurface (Export)
- (void)showExport:(NSButton *)sender;
@end
@interface DPEaselEditorSurface (Sharing)
- (void)sharePortableEditable:(BOOL)editable;
@end

NSArray<NSValue *> *DPEaselCursorRegions(DPEaselCanvas *canvas);
BOOL DPEaselCursorOverChrome(DPEaselCanvas *canvas,NSPoint windowPoint);
