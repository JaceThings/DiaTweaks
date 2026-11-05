// What one refresh does to a Space's Pull Requests folder, worked out without Dia, so tests/unit can check every rule.
#import <Foundation/Foundation.h>

// A URL's lowercase host[:port], the form the functions here take an instance's host in; nil for a URL without one.
NSString *DPGitLabURLHost(NSString *url);

// A merge request's identity across URLs that show it (its diffs, a comment anchor): "host/group/project!iid".
// nil unless the URL is a merge request on one of `hosts` (lowercase host[:port]).
NSString *DPGitLabMRKey(NSString *url, NSArray<NSString *> *hosts);

// An open merge request in one of the enabled buckets.
@interface DPGitLabMR : NSObject
@property (nonatomic, copy) NSString *key, *url, *updatedAt;
@property (nonatomic, copy) NSString *title;  // What an unloaded tab shows until it loads.
+ (instancetype)key:(NSString *)key url:(NSString *)url updatedAt:(NSString *)updatedAt;
@end

// A tab on a merge request of a configured instance, in the folder or loose in the same Space. Its id is Dia's tab id,
// which a tab has whether or not it's loaded.
@interface DPGitLabTab : NSObject
@property (nonatomic, copy) NSString *key, *tabID;
@property (nonatomic) BOOL inFolder, selected;
+ (instancetype)key:(NSString *)key tab:(NSString *)tabID inFolder:(BOOL)inFolder selected:(BOOL)selected;
@end

// What the plan remembers between refreshes of one Space.
@interface DPGitLabPlanState : NSObject <NSCopying>
@property (nonatomic, copy) NSDictionary<NSString *, NSDate *> *departures;  // When an MR in the folder left every bucket.
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *hidden;    // Closed by the user, at that updatedAt.
@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *members;   // In the folder after the last plan.
@end

@interface DPGitLabPlan : NSObject
@property (nonatomic, copy) NSArray<DPGitLabMR *> *inserts;  // Open a tab on each and put it in the folder.
@property (nonatomic, copy) NSArray<NSString *> *moves;      // Loose tabs to put in the folder.
@property (nonatomic, copy) NSArray<NSString *> *closes;     // Tabs to close.
@property (nonatomic, strong) DPGitLabPlanState *state;
@end

extern const NSTimeInterval DPGitLabDepartureGrace;  // How long a tab stays after its MR leaves the buckets.

// fetched nil means the fetch failed: nothing opens or closes. Disabled closes every folder tab but the selected one.
DPGitLabPlan *DPGitLabMakePlan(NSArray<DPGitLabTab *> *tabs, NSArray<DPGitLabMR *> *fetched, BOOL enabled,
                               DPGitLabPlanState *state, NSDate *now);
