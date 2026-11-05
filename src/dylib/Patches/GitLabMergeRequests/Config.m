#import "GitLabMergeRequests.h"
#import <Security/Security.h>

static NSString *const DPGitLabInstancesKey = @"gitlabInstances";
static NSString *const DPGitLabKeychainService = @"com.diapatches.gitlab";

static NSUserDefaults *DPGitLabDefaults(void) {
    static NSUserDefaults *defaults;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"]; });
    return defaults;
}

static NSDictionary *DPGitLabAll(void) {
    id all = [DPGitLabDefaults() objectForKey:DPGitLabInstancesKey];
    return [all isKindOfClass:NSDictionary.class] ? all : @{};
}

// The format holds a list per Space; this version shows and edits the first.
NSDictionary *DPGitLabInstance(NSString *space) {
    NSArray *list = space ? DPGitLabAll()[space] : nil;
    id first = [list isKindOfClass:NSArray.class] ? list.firstObject : nil;
    return [first isKindOfClass:NSDictionary.class] && [first[@"baseURL"] isKindOfClass:NSString.class] ? first : nil;
}

void DPGitLabSaveInstance(NSString *space, NSDictionary *instance) {
    if (!space) return;
    NSMutableDictionary *all = [DPGitLabAll() mutableCopy];
    all[space] = instance ? @[instance] : nil;
    [DPGitLabDefaults() setObject:all forKey:DPGitLabInstancesKey];
}

NSString *DPGitLabHost(NSDictionary *instance) { return DPGitLabURLHost(instance[@"baseURL"]); }

static NSDictionary *DPGitLabQuery(NSString *instanceID) {
    return @{(__bridge id)kSecClass : (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService : DPGitLabKeychainService,
             (__bridge id)kSecAttrAccount : instanceID};
}

NSString *DPGitLabToken(NSString *instanceID) {
    if (!instanceID) return nil;
    NSMutableDictionary *query = [DPGitLabQuery(instanceID) mutableCopy];
    query[(__bridge id)kSecReturnData] = @YES;
    CFTypeRef data = NULL;
    if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &data) != errSecSuccess || !data) return nil;
    NSString *token = [[NSString alloc] initWithData:(__bridge_transfer NSData *)data encoding:NSUTF8StringEncoding];
    return token.length ? token : nil;
}

BOOL DPGitLabSetToken(NSString *instanceID, NSString *token) {
    if (!instanceID) return NO;
    SecItemDelete((__bridge CFDictionaryRef)DPGitLabQuery(instanceID));
    if (!token.length) return YES;
    NSMutableDictionary *item = [DPGitLabQuery(instanceID) mutableCopy];
    item[(__bridge id)kSecValueData] = [token dataUsingEncoding:NSUTF8StringEncoding];
    item[(__bridge id)kSecAttrLabel] = @"DiaTweaks GitLab token";
    return SecItemAdd((__bridge CFDictionaryRef)item, NULL) == errSecSuccess;
}
