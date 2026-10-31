#import "Settings.h"

@implementation DPPaneView (Search)

- (BOOL)matches:(NSView *)row words:(NSArray<NSString *> *)words {
    NSString *text = [self.searchText objectForKey:row];
    for (NSString *word in words) if (word.length && ![text localizedStandardContainsString:word]) return NO;
    return YES;
}

- (void)updateRows {
    NSString *query = self.searchItem.searchField.stringValue;
    NSArray<NSString *> *words = [query componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL searching = [query stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet].length > 0;
    NSMutableSet<NSView *> *hiddenRows = [NSMutableSet set];
    for (NSSwitch *toggle in self.toggles) {
        DPPatch *patch = DPPatches[toggle.tag];
        DPPatch *disabler = DPPatchNamed(patch->disabledBy), *required = DPRequired(patch);
        toggle.state = patch->on;
        toggle.enabled = !patch->unavailable && !(disabler && disabler->on);
        if (required && !required->on) [hiddenRows addObject:toggle.superview];
    }
    BOOL anything = NO;
    for (NSArray *section in self.sections) {
        BOOL any = NO;
        for (NSView *row in section[2]) {
            BOOL visible = ![hiddenRows containsObject:row] && [self matches:row words:words];
            NSArray<NSView *> *arranged = ((NSStackView *)row.superview).arrangedSubviews;
            NSUInteger index = [arranged indexOfObject:row];
            row.hidden = !visible;
            if (index > 0) arranged[index - 1].hidden = !visible || !any;
            any |= visible;
        }
        for (NSView *view in @[section[0], section[1]]) view.hidden = !any;
        anything |= any;
    }
    self.noResults.hidden = anything;
    self.notice.hidden = searching;
}

- (void)controlTextDidChange:(NSNotification *)notification {
    [self updateRows];
}

- (void)toggle:(NSSwitch *)sender {
    DPSetPatch(DPPatches[sender.tag], sender.state == NSControlStateValueOn, YES);
    [self patchesDidChange:nil];
}

- (void)patchesDidChange:(NSNotification *)notification {
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.allowsImplicitAnimation = YES;
        [self updateRows];
        [self layoutSubtreeIfNeeded];
    }];
}
@end
