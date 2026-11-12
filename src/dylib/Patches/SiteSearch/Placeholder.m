#import "SiteSearch.h"

static char DPPlaceholderKey, DPPlaceholderLabelKey, DPPlaceholderNameKey;

// NSTextView's own placeholder, set as plain or styled text; the key it was set under goes in `key`.
static NSAttributedString *DPOwnPlaceholder(NSTextView *text, NSString **key) {
    @try {
        NSAttributedString *styled = [text valueForKey:@"placeholderAttributedString"];
        if (styled.length) return *key = @"placeholderAttributedString", styled;
        NSString *plain = [text valueForKey:@"placeholderString"];
        if (plain.length) return *key = @"placeholderString", [[NSAttributedString alloc] initWithString:plain];
    } @catch (NSException *_) {}
    return nil;
}

// Dia's "Search or enter address": a label laid over the field, if it isn't the text view's own placeholder.
static NSTextField *DPPlaceholderLabel(NSTextView *text) {
    NSView *input = text;
    while (input && !DPIsKind(input, DPDiaCommandBarInput)) input = input.superview;
    return (NSTextField *)DPFindView(input ?: text.superview, ^BOOL(NSView *view) {
        if (![view isKindOfClass:NSTextField.class] || view.hidden) return NO;
        NSTextField *field = (NSTextField *)view;
        return !field.isEditable && [field.stringValue hasPrefix:@"Search"];
    });
}

void DPSetPlaceholder(NSTextView *text, DPSite *site) {
    NSTextField *label = DPGet(text, &DPPlaceholderLabelKey);
    NSAttributedString *saved = DPGet(text, &DPPlaceholderKey);
    if (!site) {
        NSString *key = DPGet(text, &DPPlaceholderNameKey);
        if (label) label.attributedStringValue = saved;
        else if (saved && key) [text setValue:[key isEqual:@"placeholderString"] ? saved.string : saved forKey:key];
        text.needsDisplay = YES;
        DPSet(text, &DPPlaceholderKey, nil);
        DPSet(text, &DPPlaceholderNameKey, nil);
        DPSet(text, &DPPlaceholderLabelKey, nil);
        return;
    }
    if (!saved) {
        NSString *key;
        saved = DPOwnPlaceholder(text, &key);
        DPSet(text, &DPPlaceholderNameKey, key);
        if (!saved.length) {
            label = DPPlaceholderLabel(text);
            saved = label.attributedStringValue;
            DPSet(text, &DPPlaceholderLabelKey, label);
        }
        if (!saved.length) return;
        DPSet(text, &DPPlaceholderKey, saved);
    }
    NSDictionary *style = [saved attributesAtIndex:0 effectiveRange:NULL];
    NSAttributedString *words = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"Search %@", site.name] attributes:style];
    NSString *key = DPGet(text, &DPPlaceholderNameKey);
    if (label) label.attributedStringValue = words;
    else [text setValue:[key isEqual:@"placeholderString"] ? words.string : words forKey:key];
    text.needsDisplay = YES;
}
