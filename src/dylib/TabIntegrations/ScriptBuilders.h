#import "DataInternal.h"

NSString *DPIntegrationBuildPollScript(DPTabIntegration *integration);
NSString *DPIntegrationBuildInstallScript(DPTabIntegration *integration, NSString *source);
NSString *DPIntegrationBuildCommandScript(DPTabIntegration *integration, NSString *method, NSArray *arguments);
NSString *DPIntegrationBuildDisposeScript(DPTabIntegration *integration);
