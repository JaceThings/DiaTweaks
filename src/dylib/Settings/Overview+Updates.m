#import "Settings.h"

@implementation DPOverviewView (Updates)

- (NSArray<NSView *> *)makeUpdateRows {
    self.status = DPLabel(@"", 12, NSFontWeightRegular, NSColor.secondaryLabelColor);
    self.checkButton = [NSButton buttonWithTitle:@"Check for Updates" target:self action:@selector(checkForUpdates:)];
    self.relaunchButton = [NSButton buttonWithTitle:@"Relaunch to Update" target:self action:@selector(relaunchToUpdate:)];
    self.relaunchButton.bezelColor = NSColor.controlAccentColor;
    self.relaunchButton.hidden = YES;
    NSView *updateRow = DPRow(self.status, [NSStackView stackViewWithViews:@[self.relaunchButton, self.checkButton]]);
    NSSwitch *automatic = [NSSwitch new];
    automatic.controlSize = NSControlSizeSmall;
    automatic.state = DPAutoUpdates();
    automatic.target = self;
    automatic.action = @selector(toggleAutoUpdates:);
    automatic.accessibilityLabel = @"Install updates automatically";
    NSView *automaticRow = DPRow(DPColumn(@[DPLabel(@"Install updates automatically", 13, NSFontWeightRegular, NSColor.labelColor),
                                            DPLabel(@"Downloads new versions of Dia and DiaTweaks when Dia opens, and installs them when it quits.",
                                                    11, NSFontWeightRegular, NSColor.secondaryLabelColor)], 2), automatic);
    NSView *restoreRow = DPRow(DPLabel(@"Restore the original Dia without patches.", 13, NSFontWeightRegular, NSColor.labelColor),
                               [NSButton buttonWithTitle:@"Restore…" target:self action:@selector(restore:)]);
    [self.searchText setObject:@"Check for updates version" forKey:updateRow];
    [self.searchText setObject:@"Install updates automatically auto update download" forKey:automaticRow];
    [self.searchText setObject:@"Restore the original Dia without patches uninstall" forKey:restoreRow];
    return @[updateRow, automaticRow, restoreRow];
}

- (NSView *)makeSafeModeRow {
    NSView *row = DPRow(DPLabel(@"Patches are off because Dia quit unexpectedly twice right after opening.", 13, NSFontWeightRegular, NSColor.labelColor),
                        [NSButton buttonWithTitle:@"Turn Patches Back On" target:self action:@selector(leaveSafeMode:)]);
    [self.searchText setObject:@"Safe mode patches off crashed quit unexpectedly turn back on" forKey:row];
    return row;
}

- (void)showStatus:(NSDictionary *)status {
    NSString *running = [NSString stringWithFormat:@"Dia %@ (%@)",
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
        [NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]];
    id release = status[@"release"];
    if ([release isKindOfClass:NSString.class]) running = [running stringByAppendingFormat:@" · DiaTweaks %@", release];
    NSString *pending = DPPendingUpdate(status);
    self.status.stringValue = !status ? [running stringByAppendingString:@" · couldn’t check for updates"]
                            : pending ? [pending stringByAppendingString:@" installs when you quit"]
                                      : [running stringByAppendingString:@" · up to date"];
    self.relaunchButton.hidden = !pending;
    self.checkButton.enabled = YES;
}

- (void)checkForUpdates:(NSButton *)sender {
    sender.enabled = NO;
    self.status.stringValue = @"Checking for updates…";
    __weak DPOverviewView *weakSelf = self;
    DPCheckForUpdates(^(NSDictionary *status) { [weakSelf showStatus:status]; });
}

- (void)refresh {
    __weak DPOverviewView *weakSelf = self;
    DPRunCLI(@[@"status", @"--json"], ^(NSString *output) {
        id status = output ? [NSJSONSerialization JSONObjectWithData:[output dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil] : nil;
        [weakSelf showStatus:[status isKindOfClass:NSDictionary.class] ? status : nil];
    });
}

- (void)toggleAutoUpdates:(NSSwitch *)sender {
    DPSetAutoUpdates(sender.state == NSControlStateValueOn);
}

- (void)relaunchToUpdate:(id)sender {
    DPHandOffAndQuit(@"apply");
}

- (void)leaveSafeMode:(id)sender {
    DPLeaveSafeMode();
    DPHandOffAndQuit(@"apply");
}

- (void)restore:(id)sender {
    NSAlert *alert = [NSAlert new];
    alert.messageText = @"Restore the original Dia?";
    alert.informativeText = @"Dia will relaunch without patches, and its own updater takes over again. Run the installer to patch it again later.";
    [alert addButtonWithTitle:@"Restore and Relaunch"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) DPHandOffAndQuit(@"uninstall");
    }];
}
@end
