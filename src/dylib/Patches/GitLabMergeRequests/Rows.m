#import "GitLabMergeRequests.h"

// The Options of the patch's page edit the front browser window's Space, as Dia's folder belongs to one.
@interface DPGitLabRowsController : NSObject
@property (nonatomic, copy) NSString *space;
@property (nonatomic, strong) NSTextField *url, *status;
@property (nonatomic, strong) NSSecureTextField *token;
@end

@implementation DPGitLabRowsController

- (NSDictionary *)instance { return DPGitLabInstance(self.space); }

- (void)showTokenPlaceholder {
    self.token.placeholderString = DPGitLabToken(self.instance[@"id"]) ? @"Saved. Type to replace" : @"Personal access token, read_api";
}

- (void)saveURL:(NSTextField *)field {
    NSString *text = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    while ([text hasSuffix:@"/"]) text = [text substringToIndex:text.length - 1];
    NSDictionary *old = self.instance;
    if (!text.length) {
        if (old) DPGitLabSetToken(old[@"id"], nil);
        DPGitLabSaveInstance(self.space, nil);
    } else {
        if (![text containsString:@"://"]) text = [@"https://" stringByAppendingString:text];
        if (![text hasPrefix:@"https://"]) {
            self.status.stringValue = @"Use an https:// address: the token would travel in the clear.";
            field.stringValue = old[@"baseURL"] ?: @"";
            return;
        }
        NSMutableDictionary *instance = [old mutableCopy] ?: [@{@"id" : NSUUID.UUID.UUIDString, @"enabled" : @YES} mutableCopy];
        instance[@"baseURL"] = text;
        instance[@"name"] = DPGitLabHost(instance) ?: text;
        DPGitLabSaveInstance(self.space, instance);
    }
    field.stringValue = self.instance[@"baseURL"] ?: @"";
    [self showTokenPlaceholder];
    DPGitLabRefresh(YES);
}

- (void)saveToken:(NSSecureTextField *)field {
    if (!field.stringValue.length) return;
    if (!self.instance) [self saveURL:self.url];
    if (!self.instance) return (void)(self.status.stringValue = @"Enter the instance URL first.");
    self.status.stringValue = DPGitLabSetToken(self.instance[@"id"], field.stringValue) ? @"" : @"Couldn't save the token in the keychain.";
    field.stringValue = @"";
    [self showTokenPlaceholder];
    DPGitLabRefresh(YES);
}

- (void)test:(id)sender {
    if (self.url.currentEditor) [self saveURL:self.url];
    if (self.token.stringValue.length) [self saveToken:self.token];
    NSDictionary *instance = self.instance;
    if (!instance) return (void)(self.status.stringValue = @"Enter the instance URL first.");
    self.status.stringValue = @"Connecting…";
    DPGitLabFetchUser(instance[@"baseURL"], DPGitLabToken(instance[@"id"]), ^(NSString *username, NSString *error) {
        self.status.stringValue = error ? [@"Failed: " stringByAppendingString:error] : [@"Connected as " stringByAppendingString:username];
    });
}

@end

static NSView *DPGitLabRow(NSString *title, NSView *control) {
    NSStackView *row = [NSStackView stackViewWithViews:@[ [NSTextField labelWithString:title], control ]];
    row.distribution = NSStackViewDistributionEqualCentering;
    return row;
}

static NSTextField *DPGitLabField(NSTextField *field, id target, SEL action, NSString *placeholder) {
    field.placeholderString = placeholder;
    field.target = target, field.action = action;
    field.cell.sendsActionOnEndEditing = YES;
    [field.widthAnchor constraintEqualToConstant:240].active = YES;
    return field;
}

NSArray<NSView *> *DPGitLabRows(void) {
    static char key;
    DPGitLabRowsController *rows = [DPGitLabRowsController new];
    NSString *name;
    rows.space = DPGitLabFrontSpace(&name);
    if (!rows.space) return @[ DPGitLabRow(@"Profile", [NSTextField labelWithString:@"Open a Dia window first"]) ];
    rows.url = DPGitLabField([NSTextField textFieldWithString:rows.instance[@"baseURL"] ?: @""], rows, @selector(saveURL:), @"https://gitlab.com");
    rows.token = (NSSecureTextField *)DPGitLabField([NSSecureTextField new], rows, @selector(saveToken:), nil);
    [rows showTokenPlaceholder];
    rows.status = [NSTextField labelWithString:@""];
    rows.status.textColor = NSColor.secondaryLabelColor;
    NSButton *test = [NSButton buttonWithTitle:@"Test Connection" target:rows action:@selector(test:)];
    NSStackView *testRow = [NSStackView stackViewWithViews:@[ rows.status, test ]];
    NSView *profile = DPGitLabRow(@"Profile", [NSTextField labelWithString:name ?: @"This window's"]);
    objc_setAssociatedObject(profile, &key, rows, OBJC_ASSOCIATION_RETAIN_NONATOMIC);  // Lives as long as the page.
    return @[ profile, DPGitLabRow(@"Instance URL", rows.url), DPGitLabRow(@"Token", rows.token), DPGitLabRow(@"", testRow) ];
}
