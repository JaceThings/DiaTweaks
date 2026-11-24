#import <Foundation/Foundation.h>

// Input to the model is bounded and contains neither a URL's query nor its fragment.
NSString *DPTidyNameSource(NSURL *url);
BOOL DPTidyTitleNeedsRename(NSString *title);
BOOL DPTidyDownloadNeedsRename(NSString *filename);
NSString *DPTidyValidatedTitle(NSString *candidate, NSString *original);
NSString *DPTidyFallbackTitle(NSString *original);
NSString *DPTidySectionTitle(NSString *original, NSURL *url);
NSString *DPTidyCleanImageFilename(NSString *original);
NSString *DPTidyValidatedFilename(NSString *candidate, NSString *original);
NSString *DPTidyFallbackFilename(NSURL *url, NSString *original);
NSString *DPTidyImageFilename(NSURL *url, NSString *original);
BOOL DPTidyFilenameMatchesSuggestion(NSString *filename, NSString *suggestion);

// Returns a proposed label on the main queue, or nil if the model cannot name it.
void DPTidyProposeName(NSString *kind, NSString *title, NSString *source, NSString *excerpt, NSString *mediaType,
                      void (^completion)(NSString *candidate));
