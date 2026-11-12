#import <Foundation/Foundation.h>

// Every Dia but /Applications/Dia.app shares its bundle ID, so tools that look Dia up by it can't tell which to use. Launch
// Services registers an app when it is launched or moved into place; forget it after each.
void DPForgetApp(NSString *app);
