#import "Easels.h"
#import <objc/message.h>
id DPEaselRead(id object,NSString *key);
@interface DPEaselAttachment : NSObject
@property(weak) id contents;
@property(weak) NSView *pane;
@property NSView *editor;
@property DPEaselDocument *document;
@property BOOL observing,provisionalNavigation;
@property BOOL creatingEditor;
@property NSString *portableURL;
@property NSTimer *titleDelay;
@property NSString *publishedTitle,*publishedAppearance;
- (void)refresh;
@end
DPEaselAttachment *DPEaselAttachmentFor(id contents,BOOL create);
void DPEaselBindPane(id contents,NSView *pane);
void DPEaselInstallMetadataHooks(void);
void DPEaselPublishTitle(DPEaselAttachment *attachment);
NSString *DPEaselMetadataTitle(id contents);
void DPEaselRefreshMetadata(void);
void DPEaselInstallNativeAddress(void);
void DPEaselRefreshAddressFields(void);
void DPEaselUpdateAddressField(NSTextView *field);

@interface DPEaselAttachment (Portable)
- (void)tryPortableURL:(NSURL *)url;
@end
