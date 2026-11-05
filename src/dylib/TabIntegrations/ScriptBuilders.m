#import "ScriptBuilders.h"

static NSString *DPIntegrationJSON(id value) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:value options:0 error:nil];
    return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

static NSString *DPIntegrationString(NSString *value) {
    return value ? DPIntegrationJSON(@[value]) : nil;
}

static NSString *DPIntegrationEnvelope(DPTabIntegration *integration, NSString *body) {
    NSString *origins = DPIntegrationJSON(DPTabIntegrationCanonicalOrigins(integration->origins));
    if (!origins || !body) return nil;
    return [NSString stringWithFormat:@"(() => { const allowed=%@; if (!allowed.includes(location.origin)) return '{}'; %@ })()", origins, body];
}

static NSString *DPIntegrationNamespace(DPTabIntegration *integration) {
    return integration && integration->scriptNamespace ? DPIntegrationString(integration->scriptNamespace) : nil;
}

NSString *DPIntegrationBuildPollScript(DPTabIntegration *integration) {
    if (!integration) return nil;
    NSString *name = DPIntegrationNamespace(integration);
    NSString *version = [@(integration->scriptVersion) stringValue];
    if (!integration || !name.length || !version.length) return nil;
    NSString *body = [NSString stringWithFormat:
        @"const api=window[(%@)[0]]; if (!api || api.version !== %@) return JSON.stringify({installNeeded:true}); if (typeof api.snapshot !== 'function') return '{}'; return JSON.stringify(api.snapshot());",
        name, version];
    return DPIntegrationEnvelope(integration, body);
}

NSString *DPIntegrationBuildInstallScript(DPTabIntegration *integration, NSString *source) {
    if (!integration) return nil;
    NSString *name = DPIntegrationNamespace(integration);
    NSString *version = [@(integration->scriptVersion) stringValue];
    if (!integration || !name.length || !version.length || !source.length) return nil;
    NSString *body = [NSString stringWithFormat:
        @"const key=(%@)[0]; const old=window[key]; if (old && (old.version !== %@ || typeof old.snapshot !== 'function')) { if (typeof old.dispose === 'function') old.dispose(); try { delete window[key]; } catch (_) {} } %@; const api=window[key]; if (!api || api.version !== %@ || typeof api.snapshot !== 'function') return '{}'; return JSON.stringify(api.snapshot());",
        name, version, source, version];
    return DPIntegrationEnvelope(integration, body);
}

NSString *DPIntegrationBuildCommandScript(DPTabIntegration *integration, NSString *method, NSArray *arguments) {
    if (!integration) return nil;
    NSString *name = DPIntegrationNamespace(integration);
    NSString *methodJSON = DPIntegrationString(method);
    NSString *args = DPIntegrationJSON([arguments isKindOfClass:NSArray.class] ? arguments : @[]);
    if (!integration || !name || !methodJSON || !args || !method.length) return nil;
    NSString *body = [NSString stringWithFormat:
        @"const api=window[(%@)[0]]; const method=(%@)[0]; const args=%@; if (!api || api.version !== %@ || typeof api[method] !== 'function') return '{}'; api[method](...args); if (typeof api.snapshot !== 'function') return '{}'; return JSON.stringify(api.snapshot());",
        name, methodJSON, args, @(integration->scriptVersion)];
    return DPIntegrationEnvelope(integration, body);
}

NSString *DPIntegrationBuildDisposeScript(DPTabIntegration *integration) {
    if (!integration) return nil;
    NSString *name = DPIntegrationNamespace(integration);
    if (!integration || !name || !integration->scriptNamespace) return nil;
    NSString *body = [NSString stringWithFormat:
        @"const key=(%@)[0]; const api=window[key]; if (api && typeof api.dispose === 'function') api.dispose(); try { delete window[key]; } catch (_) {} return '{}';",
        name];
    return DPIntegrationEnvelope(integration, body);
}
