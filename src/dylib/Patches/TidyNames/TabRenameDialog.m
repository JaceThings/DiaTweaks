#import "Feedback.h"

BOOL DPTidyInvokeRenameAction(id target, SEL action, id sender);

static const char *const DPTidyDialogPanel =
    "_TtCC6Dialog27DialogPanelWindowControllerP33_BFC2D77BC81244121B5E5CD87796ED535Panel";

@interface DPTidyRenameRequest : NSObject
@property(weak) NSWindow *owner;
@property(weak) NSWindow *maskedPanel;
@property BOOL committing, completed, saved;
@property(copy) NSString *oldTitle, *proposedTitle;
@property(copy) dispatch_block_t didSave;
@property(copy) dispatch_block_t finished;
@property(copy) void (^sheetCompletion)(NSModalResponse);
@end
@implementation DPTidyRenameRequest @end

static DPTidyRenameRequest *DPTidyPendingRename;
static BOOL DPTidyDialogHookInstalled;
static char DPTidyHiddenRenamePanelKey;

BOOL DPTidyCommitInlineRename(NSView *row, NSString *oldTitle, NSString *name) {
    DPTidyRenameRequest *request = DPTidyPendingRename;
    NSWindow *window = row.window;
    if (!request || !window.isKeyWindow || request.owner != window || request.maskedPanel ||
        ![request.oldTitle isEqualToString:oldTitle] || ![request.proposedTitle isEqualToString:name]) return NO;

    NSTextField *field = (NSTextField *)DPFindView(row, ^BOOL(NSView *view) {
        if (![view isKindOfClass:NSTextField.class] || view.hiddenOrHasHiddenAncestor) return NO;
        NSTextField *candidate = (NSTextField *)view;
        return candidate.editable && candidate.currentEditor == window.firstResponder &&
            [candidate.stringValue isEqualToString:oldTitle];
    });
    NSTextView *editor = (NSTextView *)field.currentEditor;
    if (![editor isKindOfClass:NSTextView.class] || ![editor.string isEqualToString:oldTitle]) return NO;

    DPTidyPendingRename = nil;
    if (@available(macOS 15.0, *)) {
        NSWritingToolsBehavior behavior = editor.writingToolsBehavior;
        editor.writingToolsBehavior = NSWritingToolsBehaviorNone;
        [editor insertText:name replacementRange:NSMakeRange(0, editor.string.length)];
        [editor doCommandBySelector:@selector(insertNewline:)];
        editor.writingToolsBehavior = behavior;
    } else {
        [editor insertText:name replacementRange:NSMakeRange(0, editor.string.length)];
        [editor doCommandBySelector:@selector(insertNewline:)];
    }
    if (request.didSave) request.didSave();
    request.finished();
    return YES;
}

static NSTextField *DPTidyRenameField(NSView *root, NSString *oldTitle) {
    NSView *input = DPFindView(root, ^BOOL(NSView *view) {
        return [NSStringFromClass(view.class) isEqualToString:@"Dialog.DialogTextInput"];
    });
    return (NSTextField *)DPFindView(input, ^BOOL(NSView *view) {
        if (![view isKindOfClass:NSTextField.class]) return NO;
        NSTextField *candidate = (NSTextField *)view;
        return candidate.editable && [candidate.placeholderString isEqualToString:@"Update tab title…"] &&
            [candidate.stringValue isEqualToString:oldTitle] && candidate.delegate == (id)input &&
            [candidate.delegate respondsToSelector:@selector(controlTextDidChange:)];
    });
}

static void DPTidyMaskPanel(NSWindow *panel, DPTidyRenameRequest *request) {
    if (request.maskedPanel) return;
    request.maskedPanel = panel;
    DPSet(panel, &DPTidyHiddenRenamePanelKey, request);
    // The window's glass backdrop can survive separately from the text view.
    // Hide the entire frame before AppKit can attach or animate its material.
    panel.animationBehavior = NSWindowAnimationBehaviorNone;
    [(NSPanel *)panel setHidesOnDeactivate:YES];
    panel.level = NSNormalWindowLevel;
    panel.contentView.superview.hidden = YES;
    panel.hasShadow = NO;
    panel.alphaValue = 0;
}

static void DPTidyFinishRenamePanel(DPTidyRenameRequest *request, NSWindow *panel, BOOL saved) {
    DPTidyPendingRename = nil;
    request.completed = YES;
    request.saved = saved;
    void (^completion)(NSModalResponse) = request.sheetCompletion;
    request.sheetCompletion = nil;
    [panel orderOut:nil];
    if (completion) completion(saved ? NSModalResponseOK : NSModalResponseCancel);
    // Dia may close its sheet from the resumed task. A detached panel can
    // still be registered as a window, so close it once that task has resumed.
    dispatch_async(dispatch_get_main_queue(), ^{
        if (panel.visible || [NSApp.windows containsObject:panel]) [panel close];
        if (saved && request.didSave) request.didSave();
        request.finished();
        request.didSave = nil;
        request.finished = nil;
    });
}

static void DPTidyCommitRenamePanel(NSWindow *panel) {
    DPTidyRenameRequest *request = DPTidyPendingRename;
    if (!request || object_getClass(panel) != objc_getClass(DPTidyDialogPanel) ||
        request.committing || !request.owner.isKeyWindow || NSApp.mainWindow != request.owner ||
        (request.maskedPanel && request.maskedPanel != panel) ||
        (panel.sheetParent && panel.sheetParent != request.owner)) return;

    NSTextField *field = DPTidyRenameField(panel.contentView, request.oldTitle);
    NSButton *save = (NSButton *)DPFindView(panel.contentView, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSButton.class] && DPHasLabel(view, @"Save");
    });
    if (!field || !save) return;

    request.committing = YES;
    DPTidyMaskPanel(panel, request);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (DPTidyPendingRename != request) return;
        BOOL saved = NO;
        if (request.owner.isKeyWindow && field.window == panel && save.window == panel &&
            [field.stringValue isEqualToString:request.oldTitle]) {
            field.stringValue = request.proposedTitle;
            [field.delegate controlTextDidChange:[NSNotification notificationWithName:NSControlTextDidChangeNotification object:field]];
            if (save.enabled) {
                id target = save.target ?: [NSApp targetForAction:save.action to:nil from:save];
                saved = DPTidyInvokeRenameAction(target, save.action, save);
            }
        }
        DPTidyFinishRenamePanel(request, panel, saved);
    });
}

static void DPTidyDialogMoved(NSView *self, SEL _cmd) {
    DPCallOriginal(DPTidyDialogMoved, self);
    DPTidyRenameRequest *request = DPTidyPendingRename;
    NSWindow *panel = self.window;
    if (panel && request.owner.isKeyWindow && !panel.visible) DPTidyCommitRenamePanel(panel);
}

static BOOL DPTidySuppressRenamePanel(NSWindow *panel) {
    if (DPTidyPendingRename) DPTidyCommitRenamePanel(panel);
    // Dia can order the panel again after the Save action resolves. Keep only
    // this exact automatic panel out of the window stack for its lifetime.
    return DPGet(panel, &DPTidyHiddenRenamePanelKey) != nil;
}

static BOOL DPTidyPanelCanBecomeKey(NSWindow *self, SEL _cmd) {
    if (DPTidySuppressRenamePanel(self)) return NO;
    return DPCallOriginal(DPTidyPanelCanBecomeKey, self);
}

static void DPTidyPanelOrder(NSWindow *self, SEL _cmd, NSWindowOrderingMode place, NSInteger relativeTo) {
    if (place != NSWindowOut && DPTidySuppressRenamePanel(self)) return;
    DPCallOriginal(DPTidyPanelOrder, self, place, relativeTo);
}

static void DPTidyPanelShow(NSWindow *self, SEL _cmd, id sender) {
    if (DPTidySuppressRenamePanel(self)) return;
    DPCallOriginal(DPTidyPanelShow, self, sender);
}

static void DPTidyPanelActivate(NSWindow *self, SEL _cmd) {
    if (DPTidySuppressRenamePanel(self)) return;
    DPCallOriginal(DPTidyPanelActivate, self);
}

static void DPTidyBeginSheet(NSWindow *self, SEL _cmd, NSWindow *panel,
                             void (^completion)(NSModalResponse)) {
    DPTidyRenameRequest *request = DPGet(panel, &DPTidyHiddenRenamePanelKey);
    if (!request && DPTidyPendingRename.owner == self) {
        DPTidySuppressRenamePanel(panel);
        request = DPGet(panel, &DPTidyHiddenRenamePanelKey);
    }
    if (!request) {
        DPCallOriginal(DPTidyBeginSheet, self, panel, completion);
        return;
    }

    // Attaching a sheet dims its owner even when the panel is transparent.
    // Dia can request attachment after our Save has already run.
    if (request.completed) {
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{
            completion(request.saved ? NSModalResponseOK : NSModalResponseCancel);
        });
    } else {
        request.sheetCompletion = completion;
    }
}

static void DPTidyPanelSetAlpha(NSWindow *self, SEL _cmd, CGFloat alpha) {
    DPCallOriginal(DPTidyPanelSetAlpha, self, DPGet(self, &DPTidyHiddenRenamePanelKey) ? 0 : alpha);
}

static void DPTidyPanelSetParent(NSWindow *self, SEL _cmd, NSWindow *parent) {
    if (parent && (DPGet(self, &DPTidyHiddenRenamePanelKey) ||
                   (parent == DPTidyPendingRename.owner && DPTidySuppressRenamePanel(self)))) return;
    DPCallOriginal(DPTidyPanelSetParent, self, parent);
}

static BOOL DPTidyPanelFirstResponder(NSWindow *self, SEL _cmd, NSResponder *responder) {
    if (responder && responder != self && DPTidySuppressRenamePanel(self)) return NO;
    return DPCallOriginal(DPTidyPanelFirstResponder, self, responder);
}

void DPInstallTidyRenameDialog(void) {
    Class panel = objc_getClass(DPTidyDialogPanel);
    if (!panel) return;
    DPHook("_TtC6Dialog15DialogPanelView", @selector(viewDidMoveToWindow), (IMP)DPTidyDialogMoved);
    DPHookClass(panel, @selector(canBecomeKeyWindow), (IMP)DPTidyPanelCanBecomeKey);
    DPHookClass(panel, @selector(canBecomeMainWindow), (IMP)DPTidyPanelCanBecomeKey);
    DPHookClass(panel, @selector(orderWindow:relativeTo:), (IMP)DPTidyPanelOrder);
    DPHookClass(panel, @selector(makeKeyAndOrderFront:), (IMP)DPTidyPanelShow);
    DPHookClass(panel, @selector(orderFront:), (IMP)DPTidyPanelShow);
    DPHookClass(panel, @selector(orderFrontRegardless), (IMP)DPTidyPanelActivate);
    DPHookClass(panel, @selector(makeKeyWindow), (IMP)DPTidyPanelActivate);
    DPHookClass(panel, @selector(makeMainWindow), (IMP)DPTidyPanelActivate);
    DPHookClass(panel, @selector(becomeKeyWindow), (IMP)DPTidyPanelActivate);
    DPHookClass(panel, @selector(becomeMainWindow), (IMP)DPTidyPanelActivate);
    DPHookClass(panel, @selector(setAlphaValue:), (IMP)DPTidyPanelSetAlpha);
    DPHookClass(panel, @selector(setParentWindow:), (IMP)DPTidyPanelSetParent);
    DPHookClass(panel, @selector(makeFirstResponder:), (IMP)DPTidyPanelFirstResponder);
    DPTidyDialogHookInstalled = YES;
}

BOOL DPTidyArmRenameDialog(NSWindow *window, NSString *oldTitle, NSString *name, dispatch_block_t didSave,
                           dispatch_block_t finished) {
    if (!DPTidyDialogHookInstalled || DPTidyPendingRename) return NO;
    DPHookClass(window.class, @selector(beginSheet:completionHandler:), (IMP)DPTidyBeginSheet);
    DPTidyRenameRequest *request = [DPTidyRenameRequest new];
    request.owner = window;
    request.oldTitle = oldTitle;
    request.proposedTitle = name;
    request.didSave = didSave;
    request.finished = finished;
    DPTidyPendingRename = request;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC / 2), dispatch_get_main_queue(), ^{
        if (DPTidyPendingRename != request) return;
        DPTidyFinishRenamePanel(request, request.maskedPanel, NO);
    });
    return YES;
}
