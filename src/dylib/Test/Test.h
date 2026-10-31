// Test mode, for `make test`: with DIAPATCH_TEST=/path/report.json, Dia waits for a browser window, tries patch
// combinations without saving them, runs every patch's verify after each, ends on the saved settings and writes the report.
#import "StdPatch/StdPatch.h"

void DPRunTests(NSString *reportPath);
NSMutableArray<NSArray<NSString *> *> *DPScenarios(void);  // Scenarios.m: [name, one '0' or '1' per patch in DPPatches order]
NSString *DPBits(const int8_t *state);
