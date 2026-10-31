#import "LittleDia.h"

static char DPLittleIDKey;

NSString *DPQuoted(NSString *text) {
    text = [text stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
    return [NSString stringWithFormat:@"\"%@\"", [text stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}

// Events sent to Dia itself are handled in-process, so this needs no Automation permission.
NSAppleEventDescriptor *DPDiaScript(NSString *body) {
    NSString *source = [NSString stringWithFormat:@"tell application id %@\n%@\nend tell", DPQuoted(NSBundle.mainBundle.bundleIdentifier), body];
    NSDictionary *error = nil;
    NSAppleEventDescriptor *result = [[[NSAppleScript alloc] initWithSource:source] executeAndReturnError:&error];
    if (!result) NSLog(@"DiaPatches: Little Dia script failed: %@", error);
    return result;
}

NSString *DPLittleID(NSWindow *window) { return DPGet(window, &DPLittleIDKey); }

void DPSetLittleID(NSWindow *window, NSString *windowID) { DPSet(window, &DPLittleIDKey, windowID); }

void DPMoveToDia(NSWindow *little) {
    NSString *littleID = DPLittleID(little);
    if (!littleID) return;
    NSMutableArray<NSString *> *ids = [NSMutableArray new];
    for (NSWindow *window in DPLittleWindows) if (DPLittleID(window)) [ids addObject:DPQuoted(DPLittleID(window))];
    // Windows are listed front to back, so the first one that isn't little is the one last used.
    DPDiaScript([NSString stringWithFormat:@
        "set lw to window id %@\n"
        "set u to URL of active tab of lw\n"
        "set target to missing value\n"
        "repeat with w in windows\n"
        "  if {%@} does not contain (id of w) then\n"
        "    set target to contents of w\n"
        "    exit repeat\n"
        "  end if\n"
        "end repeat\n"
        "if u is missing value then\n"
        "  if target is not missing value then focus active tab of target\n"
        "else if target is missing value then\n"
        "  set URL of active tab of (make new window) to u\n"
        "else\n"
        "  focus (make new tab at end of tabs of target with properties {URL:u})\n"
        "end if",
        DPQuoted(littleID), [ids componentsJoinedByString:@", "]]);
    DPHideLittle(little);
}

// Little windows would otherwise come back as full windows the next time Dia opens.
void DPCloseLittleWindows(void) {
    for (NSWindow *window in DPLittleWindows.allObjects)
        if (DPLittleID(window)) DPDiaScript([NSString stringWithFormat:@"close window id %@", DPQuoted(DPLittleID(window))]);
}
