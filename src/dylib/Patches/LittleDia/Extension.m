#import "LittleDia.h"
#import "Commands/GroupTabs/GroupTabs.h"
#import <objc/message.h>
#import <CommonCrypto/CommonDigest.h>

static NSString *const kKeyword = @"diatweaks-little-dia";

static NSString *const kManifest = @"{\n"
    @"  \"manifest_version\": 3,\n"
    @"  \"name\": \"DiaTweaks Little Dia\",\n"
    @"  \"description\": \"Opens links from other apps in a small window.\",\n"
    @"  \"version\": \"1\",\n"
    @"  \"permissions\": [\"tabs\", \"search\"],\n"
    @"  \"omnibox\": { \"keyword\": \"%@\" },\n"
    @"  \"background\": { \"service_worker\": \"worker.js\" }\n"
    @"}\n";

// open: a popup with the link. The others name a popup by its page's URL. search: the words, with the profile's search
// engine, in that popup. promote: its page becomes a tab in the last normal window, which comes forward.
static NSString *const kWorker = @"const popupTab = async (url) => {\n"
    @"  const tabs = await chrome.tabs.query({ windowType: 'popup' });\n"
    @"  return tabs.find((tab) => tab.url === url) ?? (tabs.length === 1 ? tabs[0] : null);\n"
    @"};\n"
    @"chrome.omnibox.onInputEntered.addListener(async (text) => {\n"
    @"  const request = JSON.parse(text);\n"
    @"  if (request.action === 'open') {\n"
    @"    const { url, left, top, width, height } = request;\n"
    @"    return chrome.windows.create({ url, type: 'popup', focused: true, left, top, width, height });\n"
    @"  }\n"
    @"  const tab = await popupTab(request.url);\n"
    @"  if (!tab) return;\n"
    @"  if (request.action === 'search') return chrome.search.query({ text: request.text, tabId: tab.id });\n"
    @"  if (request.action !== 'promote' || !tab.url) return;\n"
    @"  const normal = await chrome.windows.getLastFocused({ windowTypes: ['normal'] }).catch(() => null);\n"
    @"  if (normal) {\n"
    @"    await chrome.tabs.create({ windowId: normal.id, url: tab.url, active: true });\n"
    @"    await chrome.windows.update(normal.id, { focused: true });\n"
    @"  } else {\n"
    @"    await chrome.windows.create({ url: tab.url, focused: true });\n"
    @"  }\n"
    @"  await chrome.windows.remove(tab.windowId);\n"
    @"});\n";

// Chromium keeps an extension's worker from its first run, whatever its version says, so a changed worker gets a new
// folder, which makes it a new extension.
static NSString *DPExtensionFolder(void) {
    uint32_t hash = 2166136261u;
    for (const char *c = kWorker.UTF8String; *c; c++) hash = (hash ^ (uint8_t)*c) * 16777619u;
    NSString *support = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject;
    return [support stringByAppendingPathComponent:[NSString stringWithFormat:@"DiaPatches/little-dia-%08x", hash]];
}

static NSString *gExtensionID;  // Set once the extension is written, for Chromium to load.

// Chromium names an unpacked extension after its folder: the SHA-256 of the path, its first 32 hex digits spelt a to p.
static NSString *DPExtensionID(NSString *folder) {
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    const char *path = folder.fileSystemRepresentation;
    CC_SHA256(path, (CC_LONG)strlen(path), digest);
    NSMutableString *id = [NSMutableString string];
    for (int i = 0; i < 16; i++) [id appendFormat:@"%c%c", 'a' + (digest[i] >> 4), 'a' + (digest[i] & 15)];
    return id;
}

void DPInstallLittleDiaExtension(void) {
    NSString *folder = DPExtensionFolder(), *parent = folder.stringByDeletingLastPathComponent;
    NSFileManager *files = NSFileManager.defaultManager;
    for (NSString *name in [files contentsOfDirectoryAtPath:parent error:nil])
        if ([name hasPrefix:@"little-dia-"] && (![name isEqual:folder.lastPathComponent] || !DPLittleDia.on))
            [files removeItemAtPath:[parent stringByAppendingPathComponent:name] error:nil];
    if (!DPLittleDia.on) return;
    NSDictionary<NSString *, NSString *> *contents = @{
        @"manifest.json" : [NSString stringWithFormat:kManifest, kKeyword],
        @"worker.js" : kWorker,
    };
    [files createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    for (NSString *name in contents)
        if (![contents[name] writeToFile:[folder stringByAppendingPathComponent:name] atomically:YES encoding:NSUTF8StringEncoding error:nil])
            return (void)NSLog(@"DiaPatches: couldn't write the Little Dia extension");
    DPLoadExtension(folder);
    gExtensionID = DPExtensionID(folder);
}

static id DPExtensions(id browser) {
    id context = [browser respondsToSelector:@selector(context)] ? DPMsg(browser, @selector(context)) : nil;
    return [context respondsToSelector:@selector(extensions)] ? DPMsg(context, @selector(extensions)) : nil;
}

// Chromium crashes on input for an extension that isn't loaded and on, as after it's turned off in Extensions.
static BOOL DPLittleDiaReady(void) {
    id browser = DPCommandBrowser();
    id extensions = DPExtensions(browser);
    SEL trigger = @selector(triggerExtensionOmniboxInput:inputText:disposition:);
    if (!gExtensionID || ![browser respondsToSelector:trigger] || ![extensions respondsToSelector:@selector(isExtensionSystemReady)]
        || !DPMsgBool(extensions, @selector(isExtensionSystemReady)) || ![extensions respondsToSelector:@selector(getExtensionInfo:)])
        return NO;
    id info = ((id (*)(id, SEL, NSString *))objc_msgSend)(extensions, @selector(getExtensionInfo:), gExtensionID);
    return [info respondsToSelector:@selector(enabled)] && DPMsgBool(info, @selector(enabled));
}

BOOL DPSendToLittleDia(NSDictionary *request) {
    if (!DPLittleDiaReady()) return NO;
    NSData *json = [NSJSONSerialization dataWithJSONObject:request options:0 error:nil];
    NSString *text = json ? [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding] : nil;
    if (!text) return NO;
    // The disposition is Chromium's WindowOpenDisposition; the worker ignores it.
    void (*send)(id, SEL, NSString *, NSString *, long) = (void *)objc_msgSend;
    send(DPCommandBrowser(), @selector(triggerExtensionOmniboxInput:inputText:disposition:), gExtensionID, text, 1);
    return YES;
}
