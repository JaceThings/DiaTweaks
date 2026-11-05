// Boosts, like Arc's: per-site hidden elements, font, CSS and JavaScript. Dia ships the engine Arc's Boosts use
// (ArcBrowserContextEffects) but never calls it, so this registers each boost there.
#import "StdPatch/StdPatch.h"
#import "Commands/GroupTabs/GroupTabs.h"

extern DPPatch DPBoosts;

// Rules.m: what a boost turns into. Foundation only, so tests/boosts.m builds it on its own. A boost is a dictionary:
// enabled, zaps (@[ @{ selector, label } ]), font, css, js.
NSString *DPBoostStylesheet(NSDictionary *boost);
NSArray<NSString *> *DPBoostHosts(NSString *domain);
BOOL DPIsBoostDomain(NSString *domain);
NSDictionary *DPCleanBoost(id raw);  // Known fields of the right types, with defaults; nil if it isn't a dictionary.
// A .diaboost file is JSON: { format: "diatweaks-boost", version: 1, domain, boost }.
NSData *DPBoostFileData(NSString *domain, NSDictionary *boost);
NSDictionary *DPBoostFromFileData(NSData *data, NSString **domain, NSString **problem);  // nil and a sentence in problem.

// Boosts.m: saved in com.diapatches under "boostSites", keyed by domain.
NSDictionary *DPBoostFor(NSString *domain);
NSArray<NSString *> *DPBoostDomains(void);
void DPSaveBoost(NSString *domain, NSDictionary *boost);  // nil deletes it. Either way Dia applies it at once.
extern NSNotificationName const DPBoostsDidChangeNotification;

// Effects.m
void DPInstallBoostEffects(void);
void DPApplyBoost(NSString *domain);
void DPApplyAllBoosts(void);
void DPLoadFavicon(NSString *domain, CGFloat points, void (^done)(NSImage *favicon));  // nil if Dia has none for it.

// Page.m: the front tab.
id DPFrontContents(void);
NSString *DPFrontDomain(void);
void DPPickElement(id contents, void (^picked)(NSDictionary *zap));  // @{ selector, label }, or nil after Escape.
void DPStopPicking(id contents);  // As if Escape: `picked` gets nil.

// Toolbar.m: the Boost button in each tab's address field.
void DPInstallBoostButton(void);
void DPSyncBoostButtons(void);
NSView *DPBoostButtonIn(NSWindow *window);  // The visible one, or nil.
NSString *DPVerifyBoostButtons(DPPatch *patch);

// Files.m: each runs on `window` as a sheet.
void DPExportBoost(NSString *domain, NSWindow *window);
void DPImportBoost(NSWindow *window);  // Opens the imported boost in the editor.

// Sites.m: the Options on Boosts' Settings page.
NSArray<NSView *> *DPBoostSettingsRows(void);
NSImageView *DPBoostFavicon(NSString *domain, CGFloat points);  // A globe until the site's favicon loads.

// Editor.m: a popover under the Boost button, else under the top of the front window.
void DPShowBoostEditor(NSString *domain);
void DPCloseBoostEditor(void);
