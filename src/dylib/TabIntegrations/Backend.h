#import "Internal.h"

// Dia-specific transport details. Adapters use Context instead of these functions.
BOOL DPIntegrationBackendAvailable(void);
NSString *DPIntegrationContentsURL(id contents);
NSString *DPIntegrationTabURL(id tab);
BOOL DPIntegrationCanEvaluate(id contents);
void DPIntegrationExecute(id contents, NSString *script, void (^completion)(NSString *result));
