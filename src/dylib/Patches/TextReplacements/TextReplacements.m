#import "StdPatch/StdPatch.h"
#import <objc/message.h>

extern DPPatch DPTextReplacements, DPTextReplacementsForms, DPTextReplacementsText, DPTextReplacementsSensitive;

// Chromium's ui::TextInputType and ui::TextInputFlags.
enum { DPInputNone = 0, DPInputPassword = 2, DPInputEmail = 4, DPInputURL = 7 };
enum { DPFlagHasBeenPassword = 1 << 12, DPFlagHasBeenCustomPassword = 1 << 14 };

static BOOL DPAllowsReplacements(id view) {
    int type = ((int (*)(id, SEL))objc_msgSend)(view, @selector(textInputType));
    int flags = ((int (*)(id, SEL))objc_msgSend)(view, @selector(textInputFlags));
    if (type == DPInputNone) return NO;
    if (type == DPInputPassword || flags & (DPFlagHasBeenPassword | DPFlagHasBeenCustomPassword)) return DPTextReplacementsSensitive.on;
    if (type == DPInputEmail || type == DPInputURL) return DPTextReplacementsForms.on;
    return DPTextReplacementsText.on;
}

// Chromium turns off Text Replacements with autocorrect, which email, URL and password fields always have off.
// Only the user's own replacements come back: no spelling corrections, quotes or dashes.
static NSTextCheckingType DPWebView_allowedTextCheckingTypes(id self, SEL _cmd) {
    NSTextCheckingType types = DPCallOriginal(DPWebView_allowedTextCheckingTypes, self);
    if (!DPTextReplacements.on || types || !DPAllowsReplacements(self)) return types;
    return NSTextCheckingTypeReplacement;
}

static void DPInstallTextReplacements(void) {
    DPHook(DPDiaWebView, @selector(allowedTextCheckingTypes), (IMP)DPWebView_allowedTextCheckingTypes);
}

DP_PATCH(DPTextReplacements) {
    .key = @"textReplacements",
    .order = 11,
    .title = @"Keyboard Text Replacements",
    .detail = @"Make your Mac's Text Replacements work in fields that pages block.",
    .symbol = @"character.cursor.ibeam text.cursor",
    .tint = @"systemBlueColor",
    .section = @"Page",
    .classes = DPClasses(DPDiaWebView),
    .install = DPInstallTextReplacements,
};

DP_PATCH(DPTextReplacementsForms) {
    .key = @"textReplacementsForms",
    .defaultOn = YES,
    .order = 13,
    .title = @"Form Fields",
    .detail = @"Use your replacements in email and web address fields, like when you sign in.",
    .symbol = @"at",
    .tint = @"systemBlueColor",
    .requires = @"textReplacements",
    .section = @"Fields",
};

DP_PATCH(DPTextReplacementsText) {
    .key = @"textReplacementsText",
    .defaultOn = YES,
    .order = 12,
    .title = @"Text Fields",
    .detail = @"Use your replacements in text fields, search boxes and editors.",
    .symbol = @"character.textbox",
    .tint = @"systemBlueColor",
    .requires = @"textReplacements",
    .section = @"Fields",
};

DP_PATCH(DPTextReplacementsSensitive) {
    .key = @"textReplacementsSensitive",
    .order = 14,
    .title = @"Sensitive Fields",
    .detail = @"Use your replacements in password fields.",
    .symbol = @"lock.fill",
    .tint = @"systemBlueColor",
    .requires = @"textReplacements",
    .section = @"Fields",
};
