#import "../dylib/Patches/TidyNames/DownloadBridge.h"
#import "../dylib/Patches/TidyNames/Names.h"

static NSDictionary *DPReadTidyMessage(void) {
    uint32_t length = 0;
    if (fread(&length, sizeof(length), 1, stdin) != 1 || !length || length > 16384) return nil;
    NSMutableData *data = [NSMutableData dataWithLength:length];
    if (fread(data.mutableBytes, 1, length, stdin) != length) return nil;
    id message = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [message isKindOfClass:NSDictionary.class] ? message : nil;
}

static void DPWriteTidyMessage(NSDictionary *message) {
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    uint32_t length = (uint32_t)data.length;
    fwrite(&length, sizeof(length), 1, stdout);
    fwrite(data.bytes, 1, data.length, stdout);
    fflush(stdout);
}

static NSString *DPTidyMessageText(NSDictionary *message, NSString *key, NSUInteger limit) {
    id value = message[key];
    return [value isKindOfClass:NSString.class] && [value length] <= limit ? value : @"";
}

static BOOL DPTidyHostEnabled(void) {
    NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.diapatches"];
    [defaults registerDefaults:@{@"tidyNames": @YES, @"tidyDownloads": @YES}];
    return [defaults boolForKey:@"tidyNames"] && [defaults boolForKey:@"tidyDownloads"];
}

static void DPTidyReportFinished(NSDictionary *message, NSString *original) {
    NSString *path = DPTidyMessageText(message, @"path", 4096);
    NSString *proposed = DPTidyMessageText(message, @"filename", 256);
    BOOL valid = [DPTidyCleanImageFilename(original) isEqualToString:proposed] ||
        [DPTidyValidatedFilename(proposed, original) isEqualToString:proposed];
    if (![path hasPrefix:@"/"] || !valid ||
        !DPTidyFilenameMatchesSuggestion(path.lastPathComponent, proposed)) return;
    NSString *digest = DPTidyDownloadPathDigest(path);
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:DPTidyDownloadFinished object:digest
        userInfo:@{@"original": original} deliverImmediately:YES];
}

static NSString *DPTidySampleFilename(NSURL *url, NSString *original) {
    if (!DPTidyNameSource(url).length ||
        [original.stringByDeletingPathExtension rangeOfString:@"sample" options:NSCaseInsensitiveSearch].location == NSNotFound)
        return nil;

    NSArray<NSString *> *hostLabels = [url.host componentsSeparatedByString:@"."];
    if (hostLabels.count < 2) return nil;
    NSUInteger index = hostLabels.count - 2;
    if (index && hostLabels.lastObject.length == 2 && hostLabels[index].length <= 3) index--;
    NSString *provider = [[hostLabels[index] stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
    NSString *extension = original.pathExtension.uppercaseString;
    NSString *label = extension.length ? [NSString stringWithFormat:@"%@ Sample %@", provider, extension] :
        [provider stringByAppendingString:@" Sample"];
    return DPTidyValidatedFilename(label, original);
}

static NSString *DPTidyFilenameLetters(NSString *filename) {
    return [[filename.stringByDeletingPathExtension.lowercaseString
        componentsSeparatedByCharactersInSet:NSCharacterSet.alphanumericCharacterSet.invertedSet]
        componentsJoinedByString:@""];
}

static NSString *DPTidyDownloadSource(NSURL *url) {
    if (![url.scheme.lowercaseString isEqualToString:@"blob"]) return DPTidyNameSource(url);
    NSURL *origin = [NSURL URLWithString:[url.absoluteString substringFromIndex:5]];
    return DPTidyNameSource(origin).length ? origin.host : @"";
}

int DPRunTidyDownloadHost(void) {
    NSDictionary *request = DPReadTidyMessage();
    NSString *original = DPTidyMessageText(request, @"original", 256);
    if (!DPTidyHostEnabled() || ![original isEqualToString:original.lastPathComponent] ||
        !DPTidyDownloadNeedsRename(original)) {
        DPWriteTidyMessage(@{});
        return 0;
    }
    NSString *operation = DPTidyMessageText(request, @"operation", 16);
    if ([operation isEqualToString:@"finished"]) {
        DPTidyReportFinished(request, original);
        DPWriteTidyMessage(@{});
        return 0;
    }

    NSURL *url = [NSURL URLWithString:DPTidyMessageText(request, @"url", 4096)];
    NSURL *referrerURL = [NSURL URLWithString:DPTidyMessageText(request, @"referrer", 4096)];
    NSString *source = DPTidyDownloadSource(url);
    NSString *referrer = DPTidyNameSource(referrerURL);
    if (![operation isEqualToString:@"suggest"]) {
        DPWriteTidyMessage(@{});
        return 0;
    }
    NSString *cleaned = DPTidyCleanImageFilename(original);
    if (cleaned) {
        DPWriteTidyMessage(@{@"filename": cleaned});
        return 0;
    }
    NSString *imageFallback = DPTidyImageFilename(referrerURL, original) ?: DPTidyImageFilename(url, original);
    if (!source.length && !referrer.length) {
        DPWriteTidyMessage(imageFallback ? @{@"filename": imageFallback} : @{});
        return 0;
    }
    NSString *subject = DPTidyFallbackFilename(url, original) ?: DPTidyFallbackFilename(referrerURL, original);
    BOOL genericImage = imageFallback && (!subject || [imageFallback.stringByDeletingPathExtension hasSuffix:@" Logo"]);
    NSString *fallback = genericImage ? imageFallback : (subject ?: DPTidySampleFilename(url, original) ?: imageFallback);
    void (^respond)(NSString *) = ^(NSString *filename) {
        DPWriteTidyMessage(filename && DPTidyHostEnabled() ? @{@"filename": filename} : @{});
        exit(0);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2800 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        respond(fallback);
    });
    NSString *kind = genericImage ? @"format-image" : @"download";
    NSString *reference = genericImage ? imageFallback.stringByDeletingPathExtension : original;
    NSString *mediaType = DPTidyMessageText(request, @"mime", 96);
    DPTidyProposeName(kind, referrer, source.length ? source : referrer, reference, mediaType, ^(NSString *candidate) {
        NSString *filename = DPTidyValidatedFilename(candidate, original);
        if (genericImage && ![DPTidyFilenameLetters(filename) isEqualToString:DPTidyFilenameLetters(fallback)])
            filename = nil;
        respond(filename ?: fallback);
    });
    dispatch_main();
}
