#import "Canvas.h"
@implementation DPEaselCanvas (ImportError)
- (void)reportImportError:(NSError *)error {
    if(!error || self.document.deleted || !self.superview || !self.window || self.window.attachedSheet || self.hiddenOrHasHiddenAncestor) return;
    NSAlert *alert=NSAlert.new; alert.messageText=@"Couldn’t add image";
    alert.informativeText=error.localizedDescription;
    [alert beginSheetModalForWindow:self.window completionHandler:nil];
}
@end
