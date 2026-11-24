#import "Feedback.h"

BOOL DPTidyArmRenameDialog(NSWindow *window, NSString *oldTitle, NSString *name, dispatch_block_t didSave,
                           dispatch_block_t finished);
BOOL DPTidyCommitInlineRename(NSView *row, NSString *oldTitle, NSString *name);
NSString *DPTidyTabIdentifier(id row);

BOOL DPTidyInvokeRenameAction(id target, SEL action, id sender) {
    if (!action || !target) return NO;
    NSMethodSignature *signature = [target methodSignatureForSelector:action];
    if (!signature || strcmp(signature.methodReturnType, @encode(void)) != 0) return NO;
    IMP implementation = [target methodForSelector:action];
    if (!implementation) return NO;
    if (signature.numberOfArguments == 2) {
        ((void (*)(id, SEL))implementation)(target, action);
    } else if (signature.numberOfArguments == 3 && [signature getArgumentTypeAtIndex:2][0] == '@') {
        ((void (*)(id, SEL, id))implementation)(target, action, sender);
    } else return NO;
    return YES;
}

static BOOL DPTidyNameIsRenameMenuItem(NSMenuItem *item) {
    NSString *title = [item.title stringByTrimmingCharactersInSet:
        [NSCharacterSet characterSetWithCharactersInString:@" .…"]];
    return item.enabled && !item.hidden &&
        [@[@"Rename", @"Rename Tab", @"Rename Current Tab"] containsObject:title];
}

NSTextField *DPTidyTabContentTitle(NSView *row) {
    return (NSTextField *)DPFindView(row, ^BOOL(NSView *view) {
        return [view isKindOfClass:NSTextField.class] && ![(NSTextField *)view isEditable] &&
            [NSStringFromClass(view.class) hasSuffix:@"FeatheredTruncatingLabel"];
    });
}

static BOOL DPTidyApplyTabRename(NSView *row, NSString *previous, NSString *name,
                                  dispatch_block_t didSave, dispatch_block_t finished) {
    NSWindow *window = row.window;
    if (!window.isKeyWindow || row.hiddenOrHasHiddenAncestor ||
        [window.firstResponder isKindOfClass:NSTextView.class]) return NO;

    BOOL favorite = DPIsKind(row, DPDiaPinnedTab);
    if (!previous.length) return NO;
    NSPoint center = [row convertPoint:NSMakePoint(NSMidX(row.bounds), NSMidY(row.bounds)) toView:nil];
    NSEvent *request = [NSEvent mouseEventWithType:NSEventTypeRightMouseDown location:center modifierFlags:0
        timestamp:NSProcessInfo.processInfo.systemUptime windowNumber:window.windowNumber context:nil
        eventNumber:0 clickCount:1 pressure:1];
    NSMenu *menu = [row menuForEvent:request];
    NSInteger index = [menu.itemArray indexOfObjectPassingTest:^BOOL(NSMenuItem *item, NSUInteger idx, BOOL *stop) {
        return DPTidyNameIsRenameMenuItem(item);
    }];
    if (!menu || index == NSNotFound) return NO;
    __weak NSView *weakRow = row;
    NSString *identifier = DPTidyTabIdentifier(row);
    if (!DPTidyArmRenameDialog(window, previous, name, didSave, finished)) return NO;
    NSMenuItem *item = [menu itemAtIndex:index];
    id target = item.target ?: [NSApp targetForAction:item.action to:nil from:item];
    // AppKit menu dispatch can temporarily change the active window. Invoke
    // the native command's action directly, retaining normal menu dispatch
    // for versions of Dia that don't expose a compatible target.
    if (!DPTidyInvokeRenameAction(target, item.action, item))
        [menu performActionForItemAtIndex:index];
    if (!favorite && !DPTidyCommitInlineRename(row, previous, name)) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSView *currentRow = weakRow;
            if ([DPTidyTabIdentifier(currentRow) isEqualToString:identifier])
                DPTidyCommitInlineRename(currentRow, previous, name);
        });
    }
    return YES;
}

static NSView *DPTidyCurrentRenameRow(NSWindow *window, NSString *identifier, BOOL favorite) {
    return DPFindView(window.contentView, ^BOOL(NSView *view) {
        return DPIsKind(view, favorite ? DPDiaPinnedTab : DPDiaTabView) && !view.hiddenOrHasHiddenAncestor &&
            [DPTidyTabIdentifier(view) isEqualToString:identifier];
    });
}

static void DPTidyConfirmSavedTitle(NSWindow *window, NSString *identifier, BOOL favorite,
                                    NSString *oldTitle, NSString *name, NSUInteger retries) {
    if (!window.isKeyWindow) return;
    NSView *row = DPTidyCurrentRenameRow(window, identifier, favorite);
    NSTextField *label = favorite ? nil : DPTidyTabContentTitle(row);
    __weak NSWindow *weakWindow = window;
    if (!row || (!favorite && ![label.stringValue isEqualToString:name])) {
        if (retries && (!label || [label.stringValue isEqualToString:oldTitle]))
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 25 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
                DPTidyConfirmSavedTitle(weakWindow, identifier, favorite, oldTitle, name, retries - 1);
            });
        return;
    }
    DPTidyPlayTitleSweep(row);
    DPTidyShowTabRename(row, oldTitle, name, ^{
        NSWindow *window = weakWindow;
        NSView *current = DPTidyCurrentRenameRow(window, identifier, favorite)
            ?: DPTidyCurrentRenameRow(window, identifier, !favorite);
        if (!current) return;
        if (!DPIsKind(current, DPDiaPinnedTab) &&
            ![DPTidyTabContentTitle(current).stringValue isEqualToString:name]) return;
        // Dia interprets an empty rename as clearing its custom title.
        DPTidyApplyTabRename(current, name, @"", nil, ^{});
    });
}

BOOL DPTidyRenameTabRow(NSView *row, NSString *previous, NSString *name, void (^finished)(BOOL saved)) {
    __weak NSWindow *weakWindow = row.window;
    NSString *identifier = DPTidyTabIdentifier(row);
    BOOL favorite = DPIsKind(row, DPDiaPinnedTab);
    __block BOOL saved = NO;
    return DPTidyApplyTabRename(row, previous, name, ^{
        saved = YES;
        dispatch_async(dispatch_get_main_queue(), ^{
            DPTidyConfirmSavedTitle(weakWindow, identifier, favorite, previous, name, 12);
        });
    }, ^{ finished(saved); });
}
