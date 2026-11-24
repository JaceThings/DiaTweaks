#import <Foundation/Foundation.h>

#define DPTidyDownloadExtensionOrigin "chrome-extension://pjcjcppokbgbngjmcdlchnbddpmllmho/"
#define DPTidyDownloadHost @"com.diapatches.tidy_downloads"
#define DPTidyDownloadFinished @"com.diapatches.tidy_downloads.finished"
#define DPTidyDownloadManifest @"Google/Chrome/NativeMessagingHosts/com.diapatches.tidy_downloads.json"
#define DPTidyDownloadExtensionFolder @"tidy-downloads-extension"

BOOL DPTidyDownloadManifestOwned(NSString *path, NSString *helper);
NSString *DPTidyDownloadPathDigest(NSString *path);
int DPRunTidyDownloadHost(void);
