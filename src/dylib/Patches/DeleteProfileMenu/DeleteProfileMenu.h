#import "StdPatch/StdPatch.h"

extern DPPatch DPDeleteProfileMenu;

// Delete.m: runs Dia's own Delete Profile… from Settings › Profiles, with Settings kept out of sight.
void DPDeleteProfile(NSWindow *window, NSString *name, NSUInteger index, NSMenuItem *settings);
BOOL DPDeletingProfile(void);
void DPEndProfileDelete(void);

// Settings.m: the Settings window, hidden while a delete runs.
NSWindow *DPSettingsWindow(BOOL visibleOnly);
void DPHideSettings(NSWindow *settings);
void DPShowSettings(NSWindow *settings);
BOOL DPSettingsHidden(NSWindow *settings);
