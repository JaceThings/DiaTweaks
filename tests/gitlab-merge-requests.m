// make check: the GitLab merge requests patch's refresh rules, without Dia.
#import "Patches/GitLabMergeRequests/Plan.h"

static int failures, checks;
#define CHECK(cond, ...) do { checks++; if (!(cond)) { failures++; fprintf(stderr, "FAIL %s:%d: ", __FILE__, __LINE__); fprintf(stderr, __VA_ARGS__); fprintf(stderr, "\n"); } } while (0)

static NSArray *hosts;
static DPGitLabMR *mr(NSString *key, NSString *updated) { return [DPGitLabMR key:key url:[@"https://" stringByAppendingString:key] updatedAt:updated]; }
static NSString *tid(long long n) { return [NSString stringWithFormat:@"tab-%lld", n]; }
static DPGitLabTab *folderTab(NSString *key, long long n) { return [DPGitLabTab key:key tab:tid(n) inFolder:YES selected:NO]; }
static DPGitLabTab *selectedTab(NSString *key, long long n) { return [DPGitLabTab key:key tab:tid(n) inFolder:YES selected:YES]; }
static DPGitLabTab *looseTab(NSString *key, long long n) { return [DPGitLabTab key:key tab:tid(n) inFolder:NO selected:NO]; }
static NSDate *at(NSTimeInterval t) { return [NSDate dateWithTimeIntervalSince1970:t]; }
static NSArray *keys(NSArray<DPGitLabMR *> *mrs) { return [mrs valueForKey:@"key"]; }

static void testKeys(void) {
    CHECK([DPGitLabMRKey(@"https://code.example.org/mobile/app/-/merge_requests/1", hosts) isEqual:@"code.example.org/mobile/app!1"], "plain MR URL");
    CHECK([DPGitLabMRKey(@"https://Code.Example.ORG/a/b/c/-/merge_requests/12/diffs#note_3", hosts) isEqual:@"code.example.org/a/b/c!12"], "diffs, anchor, case and subgroups map to the MR");
    CHECK([DPGitLabMRKey(@"https://gitlab.example:8443/g/p/-/merge_requests/7?tab=x", hosts) isEqual:@"gitlab.example:8443/g/p!7"], "port kept");
    CHECK(!DPGitLabMRKey(@"https://github.com/a/b/pull/1", hosts), "other host");
    CHECK(!DPGitLabMRKey(@"https://code.example.org/mobile/app/-/merge_requests", hosts), "the MR list");
    CHECK(!DPGitLabMRKey(@"https://code.example.org/mobile/app/-/merge_requests/new", hosts), "new MR form");
    CHECK(!DPGitLabMRKey(@"https://code.example.org/-/merge_requests/3", hosts), "no project");
    CHECK(!DPGitLabMRKey(@"https://code.example.org/a/b/-/issues/3", hosts), "an issue");
    CHECK(!DPGitLabMRKey(@"javascript:alert(1)", hosts), "not http");
    CHECK(!DPGitLabMRKey(nil, hosts), "nil");
    CHECK([DPGitLabURLHost(@"https://GitLab.example:8443/x") isEqual:@"gitlab.example:8443"] && !DPGitLabURLHost(@"not a url"), "hosts");
}

static void testOffAndOnAgain(void) {
    DPGitLabPlan *on = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[mr(@"h/p!1", @"t1")], YES, nil, at(0));
    DPGitLabPlan *off = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], NO, on.state, at(60));
    CHECK([off.closes isEqual:@[tid(10)]], "turning it off closes its tabs");
    DPGitLabPlan *again = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, off.state, at(120));
    CHECK([keys(again.inserts) isEqual:@[@"h/p!1"]], "and turning it on opens them again: closing them wasn't the user's doing");
}

static void testInsertAndMove(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[looseTab(@"h/p!2", 20)], @[mr(@"h/p!1", @"t1"), mr(@"h/p!2", @"t1")], YES, nil, at(0));
    CHECK([keys(plan.inserts) isEqual:@[@"h/p!1"]], "an MR with no tab is opened: %s", [keys(plan.inserts) description].UTF8String);
    CHECK([plan.moves isEqual:@[tid(20)]], "an MR already open loose is moved in, not opened twice");
    CHECK(plan.closes.count == 0, "nothing closes");
    plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[mr(@"h/p!1", @"t1")], YES, nil, at(0));
    CHECK(!plan.inserts.count && !plan.moves.count && !plan.closes.count, "an MR already in the folder is left alone");
}

static void testDepartureGrace(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, nil, at(1000));
    CHECK(plan.closes.count == 0, "a tab stays when its MR first leaves the buckets");
    CHECK([plan.state.departures[@"h/p!1"] isEqual:at(1000)], "and the departure is remembered");
    DPGitLabPlan *before = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, plan.state, at(1000 + DPGitLabDepartureGrace - 1));
    CHECK(before.closes.count == 0, "still there just before the grace runs out");
    DPGitLabPlan *after = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, before.state, at(1000 + DPGitLabDepartureGrace));
    CHECK([after.closes isEqual:@[tid(10)]], "closed once the grace runs out");
    CHECK(!after.state.departures[@"h/p!1"] && !after.state.members[@"h/p!1"], "and forgotten");
    DPGitLabPlan *back = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[mr(@"h/p!1", @"t2")], YES, plan.state, at(1100));
    CHECK(!back.closes.count && !back.state.departures[@"h/p!1"], "an MR that returns to a bucket clears its departure");
}

static void testSelectedNeverCloses(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[selectedTab(@"h/p!1", 10)], @[], YES, nil, at(0));
    plan = DPGitLabMakePlan(@[selectedTab(@"h/p!1", 10)], @[], YES, plan.state, at(DPGitLabDepartureGrace * 3));
    CHECK(plan.closes.count == 0, "the selected tab outlives the grace");
    plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, plan.state, at(DPGitLabDepartureGrace * 3 + 1));
    CHECK([plan.closes isEqual:@[tid(10)]], "and closes once it's no longer selected");
    plan = DPGitLabMakePlan(@[selectedTab(@"h/p!1", 10), folderTab(@"h/p!2", 11)], @[mr(@"h/p!1", @"t"), mr(@"h/p!2", @"t")], NO, nil, at(0));
    CHECK([plan.closes isEqual:@[tid(11)]], "turning it off closes every folder tab but the selected one: %s", plan.closes.description.UTF8String);
}

static void testUserClosed(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[mr(@"h/p!1", @"t1")], YES, nil, at(0));
    CHECK([plan.state.members[@"h/p!1"] isEqual:@"t1"], "a tab seen in the folder is a member");
    DPGitLabPlan *gone = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, plan.state, at(60));
    CHECK(!gone.inserts.count, "a member the user closed isn't opened again");
    CHECK([gone.state.hidden[@"h/p!1"] isEqual:@"t1"], "it's hidden at the updatedAt it had");
    DPGitLabPlan *same = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, gone.state, at(120));
    CHECK(!same.inserts.count, "still hidden while it hasn't changed");
    DPGitLabPlan *changed = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t2")], YES, same.state, at(180));
    CHECK([keys(changed.inserts) isEqual:@[@"h/p!1"]] && !changed.state.hidden[@"h/p!1"], "back once it changes");
    DPGitLabPlan *dragged = DPGitLabMakePlan(@[looseTab(@"h/p!1", 10)], @[mr(@"h/p!1", @"t1")], YES, plan.state, at(60));
    CHECK(!dragged.moves.count, "one dragged out of the folder isn't pulled back");
    DPGitLabPlan *merged = DPGitLabMakePlan(@[], @[], YES, gone.state, at(240));
    CHECK(!merged.state.hidden[@"h/p!1"], "forgotten once the MR isn't open");
}

static void testInsertThatDidNotLand(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, nil, at(0));
    CHECK([keys(plan.inserts) isEqual:@[@"h/p!1"]], "opened");
    plan = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, plan.state, at(300));
    CHECK([keys(plan.inserts) isEqual:@[@"h/p!1"]], "an insert that never showed up in the folder is tried again, not taken as closed by the user");
}

static void testFailedFetch(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, nil, at(0));
    DPGitLabPlan *failed = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], nil, YES, plan.state, at(DPGitLabDepartureGrace * 2));
    CHECK(!failed.closes.count && !failed.inserts.count, "a failed fetch opens and closes nothing");
    CHECK([failed.state.departures[@"h/p!1"] isEqual:at(0)], "and keeps the departure clock");
    DPGitLabPlan *next = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], @[], YES, failed.state, at(DPGitLabDepartureGrace * 2 + 1));
    CHECK([next.closes isEqual:@[tid(10)]], "the next good fetch closes it at once");
}

static void testClosedBeforeAnyFetch(void) {
    DPGitLabPlan *failed = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10)], nil, YES, nil, at(0));
    DPGitLabPlan *closed = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t1")], YES, failed.state, at(60));
    CHECK(!closed.inserts.count, "a tab the user closed before any fetch succeeded isn't opened again");
    DPGitLabPlan *changed = DPGitLabMakePlan(@[], @[mr(@"h/p!1", @"t2")], YES, closed.state, at(120));
    CHECK([keys(changed.inserts) isEqual:@[@"h/p!1"]], "until its MR changes");
}

static void testDuplicates(void) {
    DPGitLabPlan *plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10), folderTab(@"h/p!1", 11)], @[mr(@"h/p!1", @"t")], YES, nil, at(0));
    CHECK([plan.closes isEqual:@[tid(11)]], "a second folder tab on the same MR closes: %s", plan.closes.description.UTF8String);
    plan = DPGitLabMakePlan(@[folderTab(@"h/p!1", 10), selectedTab(@"h/p!1", 11)], @[mr(@"h/p!1", @"t")], YES, nil, at(0));
    CHECK([plan.closes isEqual:@[tid(10)]], "keeping the selected one");
}

int main(void) {
    @autoreleasepool {
        hosts = @[@"code.example.org", @"gitlab.example:8443"];
        testKeys();
        testInsertAndMove();
        testOffAndOnAgain();
        testDepartureGrace();
        testSelectedNeverCloses();
        testUserClosed();
        testInsertThatDidNotLand();
        testFailedFetch();
        testClosedBeforeAnyFetch();
        testDuplicates();
    }
    printf("%d checks, %d failed\n", checks, failures);
    return failures ? 1 : 0;
}
