#import "GitLabMergeRequests.h"

static const NSInteger DPGitLabMaxPages = 5;  // 500 MRs a bucket.

// The token rides in a header, which URLSession would carry to wherever a redirect points: follow none that leave the
// instance or https.
@interface DPGitLabSessionDelegate : NSObject <NSURLSessionTaskDelegate>
@end

@implementation DPGitLabSessionDelegate
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    NSURL *from = task.originalRequest.URL, *to = request.URL;
    BOOL same = [to.scheme isEqual:@"https"] && [to.host.lowercaseString isEqual:from.host.lowercaseString] && [to.port ?: @443 isEqual:from.port ?: @443];
    completionHandler(same ? request : nil);
}
@end

static NSURLSession *DPGitLabSession(void) {
    static NSURLSession *session;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSURLSessionConfiguration *config = NSURLSessionConfiguration.ephemeralSessionConfiguration;
        config.timeoutIntervalForRequest = 15;
        config.HTTPCookieStorage = nil;  // The token is the only credential, never a session in a cookie.
        session = [NSURLSession sessionWithConfiguration:config delegate:[DPGitLabSessionDelegate new] delegateQueue:nil];
    });
    return session;
}

static NSString *DPGitLabAPI(NSString *baseURL, NSString *path) {
    while ([baseURL hasSuffix:@"/"]) baseURL = [baseURL substringToIndex:baseURL.length - 1];
    return [NSString stringWithFormat:@"%@/api/v4/%@", baseURL, path];
}

static NSString *DPGitLabErrorFor(NSHTTPURLResponse *response, NSError *error) {
    if (error) return error.code == NSURLErrorCancelled ? @"cancelled" : @"unreachable";
    if (response.statusCode == 401 || response.statusCode == 403) return @"token expired";
    if (response.statusCode == 404 || (response.statusCode >= 300 && response.statusCode < 400)) return @"not a GitLab instance";
    return response.statusCode == 200 ? nil : [NSString stringWithFormat:@"HTTP %ld", (long)response.statusCode];
}

// Calls back on the main queue with the decoded JSON, or an error.
static void DPGitLabGet(NSString *url, NSString *token, void (^done)(id json, NSHTTPURLResponse *response, NSString *error)) {
    NSURL *address = [NSURL URLWithString:url];
    if (!token.length) return done(nil, nil, @"no token");
    if (![address.scheme isEqual:@"https"] || !address.host.length) return done(nil, nil, @"instance URL must be https");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:address];
    [request setValue:token forHTTPHeaderField:@"PRIVATE-TOKEN"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    [[DPGitLabSession() dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSHTTPURLResponse *http = [response isKindOfClass:NSHTTPURLResponse.class] ? (NSHTTPURLResponse *)response : nil;
        NSString *failure = DPGitLabErrorFor(http, error);
        id json = !failure && data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL] : nil;
        if (!failure && !json) failure = @"not a GitLab instance";
        dispatch_async(dispatch_get_main_queue(), ^{ done(json, http, failure); });
    }] resume];
}

void DPGitLabFetchUser(NSString *baseURL, NSString *token, void (^done)(NSString *username, NSString *error)) {
    DPGitLabGet(DPGitLabAPI(baseURL, @"user"), token, ^(id json, NSHTTPURLResponse *response, NSString *error) {
        NSString *name = [json isKindOfClass:NSDictionary.class] ? json[@"username"] : nil;
        if (!error && ![name isKindOfClass:NSString.class]) error = @"not a GitLab instance", name = nil;
        done(name, error);
    });
}

// Every page of one bucket, as DPGitLabMR, keyed for the instance's host.
static void DPGitLabFetchBucket(NSDictionary *instance, NSString *token, NSString *query, NSInteger page, NSMutableArray *into,
                                void (^done)(NSString *error)) {
    NSString *path = [NSString stringWithFormat:@"merge_requests?%@&state=opened&per_page=100&page=%ld", query, (long)page];
    DPGitLabGet(DPGitLabAPI(instance[@"baseURL"], path), token, ^(id json, NSHTTPURLResponse *response, NSString *error) {
        if (error || ![json isKindOfClass:NSArray.class]) return done(error ?: @"not a GitLab instance");
        NSArray *hosts = @[DPGitLabHost(instance) ?: @""];
        for (NSDictionary *item in json) {
            if (![item isKindOfClass:NSDictionary.class] || ![item[@"web_url"] isKindOfClass:NSString.class]) continue;
            NSString *key = DPGitLabMRKey(item[@"web_url"], hosts);
            NSString *updated = [item[@"updated_at"] isKindOfClass:NSString.class] ? item[@"updated_at"] : @"";
            if (!key) continue;
            DPGitLabMR *mr = [DPGitLabMR key:key url:item[@"web_url"] updatedAt:updated];
            NSString *title = [item[@"title"] isKindOfClass:NSString.class] ? item[@"title"] : @"";
            NSString *ref = [item[@"references"] isKindOfClass:NSDictionary.class] ? item[@"references"][@"short"] : nil;
            mr.title = [ref isKindOfClass:NSString.class] ? [NSString stringWithFormat:@"%@ (%@)", title, ref] : title;
            [into addObject:mr];
        }
        NSInteger next = [[response valueForHTTPHeaderField:@"x-next-page"] integerValue];
        if (next > page && next <= DPGitLabMaxPages) return DPGitLabFetchBucket(instance, token, query, next, into, done);
        done(nil);
    });
}

// Each enabled bucket's merge requests, once each. Review Requests asks who the user is, which Created by Me doesn't need.
void DPGitLabFetchMRs(NSDictionary *instance, NSString *token, BOOL created, BOOL review,
                      void (^done)(NSArray<DPGitLabMR *> *mrs, NSString *error)) {
    if (!created && !review) return done(@[], nil);  // Both of the folder's switches off: no merge requests wanted.
    void (^fetch)(NSString *) = ^(NSString *username) {
        NSMutableArray *queries = [NSMutableArray new];
        if (created) [queries addObject:@"scope=created_by_me"];
        if (username) [queries addObject:[@"scope=all&reviewer_username=" stringByAppendingString:
                                              [username stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet]]];
        NSMutableArray *all = [NSMutableArray new];
        __block NSUInteger index = 0;
        __block void (^next)(NSString *);
        next = ^(NSString *failure) {
            if (failure || index == queries.count) {
                next = nil;  // Ends the cycle between the block and itself.
                if (failure) return done(nil, failure);
                NSMutableDictionary *seen = [NSMutableDictionary new];  // In both buckets: once.
                NSMutableArray *unique = [NSMutableArray new];
                for (DPGitLabMR *mr in all)
                    if (!seen[mr.key]) seen[mr.key] = mr, [unique addObject:mr];
                return done(unique, nil);
            }
            DPGitLabFetchBucket(instance, token, queries[index++], 1, all, next);
        };
        next(nil);
    };
    if (!review) return fetch(nil);
    DPGitLabFetchUser(instance[@"baseURL"], token, ^(NSString *username, NSString *error) {
        if (error) return done(nil, error);
        fetch(username);
    });
}
