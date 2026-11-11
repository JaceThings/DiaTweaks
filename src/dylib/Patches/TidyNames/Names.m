#import "Names.h"
#import "DownloadBridge.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *DPTidyCleanName(NSString *value) {
    NSArray *parts = [value componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    return [[parts filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"length > 0"]]
        componentsJoinedByString:@" "];
}

static BOOL DPTidyIsImageExtension(NSString *extension) {
    return [@[@"avif", @"gif", @"heic", @"jpeg", @"jpg", @"png", @"webp"] containsObject:extension.lowercaseString];
}

static BOOL DPTidyIsGenericLogo(NSString *stem) {
    return [stem.lowercaseString rangeOfString:@"^(?:[a-z][_. -])?logos?$" options:NSRegularExpressionSearch].location != NSNotFound;
}

static NSString *DPTidyImageStem(NSString *filename) {
    NSString *stem = filename.stringByDeletingPathExtension;
    while (DPTidyIsImageExtension(stem.pathExtension)) stem = stem.stringByDeletingPathExtension;
    return stem;
}

NSString *DPTidyCleanImageFilename(NSString *original) {
    if (!DPTidyIsImageExtension(original.pathExtension)) return nil;
    NSString *stem = DPTidyImageStem(original);
    if ([stem isEqualToString:original.stringByDeletingPathExtension] && ![stem containsString:@"_"]) return nil;
    if (DPTidyIsGenericLogo(stem)) return nil;
    NSString *clean = DPTidyCleanName([stem stringByReplacingOccurrencesOfString:@"_" withString:@" "]);
    clean = [clean stringByReplacingOccurrencesOfString:@"[ ]+20[0-9]{2}[ -][0-9]{2}[ -][0-9]{2}$"
                                             withString:@"" options:NSRegularExpressionSearch range:NSMakeRange(0, clean.length)];
    NSUInteger subjectWords = 0;
    for (NSString *word in [clean componentsSeparatedByString:@" "]) {
        if (word.length > 1 && [word rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound)
            subjectWords++;
    }
    if (subjectWords < 2 || clean.length > 120 ||
        [clean rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location == NSNotFound ||
        [clean rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\:\""]].location != NSNotFound ||
        [clean rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound ||
        [clean hasPrefix:@"."] || [clean hasSuffix:@"."]) return nil;
    return [clean.precomposedStringWithCanonicalMapping stringByAppendingPathExtension:original.pathExtension];
}

NSString *DPTidyNameSource(NSURL *url) {
    if (!url) return @"";
    NSURLComponents *parts = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
    if (!parts.host.length || ![@[@"http", @"https"] containsObject:parts.scheme.lowercaseString]) return @"";
    NSString *source = [parts.host stringByAppendingString:parts.path ?: @""];
    if (source.length <= 180) return source;
    return [source substringToIndex:[source rangeOfComposedCharacterSequenceAtIndex:179].location];
}

BOOL DPTidyTitleNeedsRename(NSString *title) {
    NSString *clean = DPTidyCleanName(title);
    return clean.length > 32 || [clean componentsSeparatedByString:@" "].count > 3;
}

BOOL DPTidyDownloadNeedsRename(NSString *filename) {
    NSString *stem = DPTidyCleanName(filename.stringByDeletingPathExtension).lowercaseString;
    if (!stem.length) return NO;
    if (DPTidyIsImageExtension(filename.pathExtension) &&
        (DPTidyIsGenericLogo(stem) || DPTidyCleanImageFilename(filename))) return YES;
    // Leave names containing meaningful words alone, even when they end with an ID.
    static NSRegularExpression *noise;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        noise = [NSRegularExpression regularExpressionWithPattern:
            @"^(?:_+(?: \\([0-9]+\\))?|[0-9][0-9 _.-]{3,}|[a-f0-9]{12,}|(?=[a-z0-9]{12,}$)(?:[a-z]+[0-9]+){4,}[a-z]*|[a-f0-9]{8}(?:-[a-f0-9]{4}){3}-[a-f0-9]{12}|"
             @"(?:download|file|untitled|document|export|attachment|images?|img|dsc|pxl|scan|dummy|(?:(?:pdf|file)[ _.-]+)?sample(?:[ _.-]+(?:pdf|file|document))?)(?:[ _().-]*[0-9][0-9 _().-]*(?:kb|mb|gb)?)?)$"
            options:0 error:nil];
    });
    return [noise firstMatchInString:stem options:0 range:NSMakeRange(0, stem.length)] != nil;
}

static BOOL DPTidySafeLabel(NSString *value) {
    if (!value.length || [value hasPrefix:@"."]) return NO;
    if ([value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound ||
        [value rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/\\:\""]].location != NSNotFound)
        return NO;
    return [value rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet].location != NSNotFound;
}

NSString *DPTidyValidatedTitle(NSString *candidate, NSString *original) {
    NSString *clean = DPTidyCleanName(candidate);
    NSUInteger words = [clean componentsSeparatedByString:@" "].count;
    if (!DPTidySafeLabel(clean) || words < 2 || words > 3 || clean.length > 40 ||
        [clean caseInsensitiveCompare:DPTidyCleanName(original)] == NSOrderedSame) return nil;
    NSArray<NSString *> *source = [DPTidyCleanName(original) componentsSeparatedByString:@" "];
    NSUInteger index = 0;
    NSCharacterSet *punctuation = NSCharacterSet.punctuationCharacterSet;
    for (NSString *word in [clean componentsSeparatedByString:@" "]) {
        while (index < source.count &&
            [[source[index] stringByTrimmingCharactersInSet:punctuation] caseInsensitiveCompare:word] != NSOrderedSame) index++;
        if (index == source.count) return nil;
        index++;
    }
    return clean;
}

NSString *DPTidySectionTitle(NSString *original, NSURL *url) {
    NSString *section = url.path.lastPathComponent.lowercaseString;
    if (![@[@"members", @"team", @"events", @"pricing", @"docs", @"careers", @"about"] containsObject:section]) return nil;
    NSArray<NSString *> *hostLabels = [url.host.lowercaseString componentsSeparatedByString:@"."];
    if (hostLabels.count < 2) return nil;
    NSString *site = [hostLabels[hostLabels.count - 2] stringByReplacingOccurrencesOfString:@"-" withString:@""];
    if (site.length < 3) return nil;
    NSString *titleParts = [DPTidyCleanName(original) stringByReplacingOccurrencesOfString:@" - " withString:@" | "];
    for (NSString *part in [titleParts componentsSeparatedByCharactersInSet:
             [NSCharacterSet characterSetWithCharactersInString:@"|—–"]]) {
        NSString *brand = [part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        NSArray<NSString *> *words = [brand componentsSeparatedByString:@" "];
        if (words.count > 2 || !DPTidySafeLabel(brand)) continue;
        NSString *joined = [[brand.lowercaseString stringByReplacingOccurrencesOfString:@" " withString:@""]
            stringByReplacingOccurrencesOfString:@"-" withString:@""];
        if ([joined isEqualToString:site] || [words.lastObject.lowercaseString isEqualToString:site]) {
            NSString *title = [NSString stringWithFormat:@"%@ %@", brand, section.capitalizedString];
            if (title.length <= 40 && [title caseInsensitiveCompare:original] != NSOrderedSame) return title;
        }
    }
    return nil;
}

NSString *DPTidyFallbackTitle(NSString *original) {
    NSString *title = DPTidyCleanName(original);
    for (NSString *separator in @[@" | ", @" — ", @" – ", @" - "])
        title = [title componentsSeparatedByString:separator].firstObject;
    NSMutableArray<NSString *> *words = [NSMutableArray new];
    NSCharacterSet *punctuation = NSCharacterSet.punctuationCharacterSet;
    for (NSString *word in [title componentsSeparatedByString:@" "]) {
        NSString *plain = [word stringByTrimmingCharactersInSet:punctuation];
        if (!DPTidySafeLabel(plain)) continue;
        if (!words.count && [@[@"a", @"an", @"the"] containsObject:plain.lowercaseString]) continue;
        [words addObject:plain];
        if (words.count == 3) break;
    }
    if ([@[@"and", @"or", @"for", @"of", @"to", @"with", @"in", @"on"] containsObject:words.lastObject.lowercaseString ?: @""])
        [words removeLastObject];
    return DPTidyValidatedTitle([words componentsJoinedByString:@" "], original);
}

NSString *DPTidyValidatedFilename(NSString *candidate, NSString *original) {
    NSString *extension = original.pathExtension;
    NSString *stem = DPTidyCleanName(candidate);
    if (extension.length && [stem.pathExtension caseInsensitiveCompare:extension] == NSOrderedSame)
        stem = stem.stringByDeletingPathExtension;
    NSUInteger words = [stem componentsSeparatedByString:@" "].count;
    if (!DPTidySafeLabel(stem) || words < 2 || words > 6 || stem.pathExtension.length || stem.length > 80 ||
        [stem hasSuffix:@"."] || [stem lengthOfBytesUsingEncoding:NSUTF8StringEncoding] > 180) return nil;
    NSString *result = extension.length ? [stem stringByAppendingPathExtension:extension] : stem;
    if ([result caseInsensitiveCompare:original] == NSOrderedSame || DPTidyDownloadNeedsRename(result)) return nil;
    return result;
}

NSString *DPTidyFallbackFilename(NSURL *url, NSString *original) {
    if (!DPTidyNameSource(url).length) return nil;
    NSArray<NSString *> *path = url.path.pathComponents;
    NSMutableArray<NSString *> *words = [NSMutableArray new];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"-_. "];
    for (NSString *part in path.reverseObjectEnumerator) {
        if ([part isEqualToString:@"/"] || DPTidyDownloadNeedsRename(part)) continue;
        NSString *slug = part;
        if (slug.pathExtension.length &&
            ([slug.pathExtension caseInsensitiveCompare:original.pathExtension] == NSOrderedSame ||
             (DPTidyIsImageExtension(original.pathExtension) && DPTidyIsImageExtension(slug.pathExtension))))
            slug = slug.stringByDeletingPathExtension;
        NSMutableArray<NSString *> *segment = [NSMutableArray new];
        for (NSString *word in [slug componentsSeparatedByCharactersInSet:separators]) {
            if (word.length < 2 || word.length > 25 ||
                [word rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet.invertedSet].location != NSNotFound ||
                [@[@"api", @"download", @"downloads", @"file", @"files", @"index", @"view", @"content", @"default",
                    @"public", @"static", @"assets", @"sites", @"storage", @"uploads", @"id", @"html", @"aspx", @"php",
                    @"originals", @"media", @"images", @"image", @"thumbnail", @"thumbnails"] containsObject:word.lowercaseString])
                continue;
            [segment addObject:word.capitalizedString];
            if (segment.count == 4) break;
        }
        if (segment.count) {
            [words insertObjects:segment atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, segment.count)]];
            if (words.count >= 2)
                return DPTidyValidatedFilename([words componentsJoinedByString:@" "], original);
        }
    }
    return nil;
}

BOOL DPTidyFilenameMatchesSuggestion(NSString *filename, NSString *suggestion) {
    if ([filename isEqualToString:suggestion]) return YES;
    if (![filename.pathExtension isEqualToString:suggestion.pathExtension]) return NO;
    // Chromium may append a number to avoid overwriting a file.
    NSString *stem = filename.stringByDeletingPathExtension;
    NSString *prefix = [suggestion.stringByDeletingPathExtension stringByAppendingString:@" ("];
    if (![stem hasPrefix:prefix] || ![stem hasSuffix:@")"] || stem.length <= prefix.length + 1) return NO;
    NSString *number = [stem substringWithRange:NSMakeRange(prefix.length, stem.length - prefix.length - 1)];
    return number.integerValue > 0 &&
        [number rangeOfCharacterFromSet:NSCharacterSet.decimalDigitCharacterSet.invertedSet].location == NSNotFound;
}

NSString *DPTidyImageFilename(NSURL *url, NSString *original) {
    if (!DPTidyIsImageExtension(original.pathExtension) ||
        !DPTidyDownloadNeedsRename(original)) return nil;
    if ([url.scheme.lowercaseString isEqualToString:@"blob"])
        url = [NSURL URLWithString:[url.absoluteString substringFromIndex:5]];
    if (!DPTidyNameSource(url).length) return nil;

    NSArray<NSString *> *labels = [url.host.lowercaseString componentsSeparatedByString:@"."];
    if (labels.count < 2 || ![labels.lastObject canBeConvertedToEncoding:NSASCIIStringEncoding] ||
        [labels.lastObject rangeOfCharacterFromSet:NSCharacterSet.letterCharacterSet.invertedSet].location != NSNotFound)
        return nil;
    NSUInteger index = labels.count - 2;
    if (index && labels.lastObject.length == 2 &&
        [@[@"co", @"com", @"net", @"org"] containsObject:labels[index]]) index--;
    NSString *site = labels[index];
    NSString *label = [[site stringByReplacingOccurrencesOfString:@"-" withString:@" "] capitalizedString];
    NSString *kind = DPTidyIsGenericLogo(original.stringByDeletingPathExtension) ? @"Logo" : @"Image";
    return DPTidyValidatedFilename([NSString stringWithFormat:@"%@ %@", label, kind], original);
}


BOOL DPTidyDownloadManifestOwned(NSString *path, NSString *helper) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (!data) return NO;
    NSDictionary *manifest = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    return [manifest isKindOfClass:NSDictionary.class] &&
        [manifest[@"name"] isEqual:DPTidyDownloadHost] &&
        [manifest[@"allowed_origins"] isEqual:@[@DPTidyDownloadExtensionOrigin]] &&
        [manifest[@"path"] isEqual:helper];
}

NSString *DPTidyDownloadPathDigest(NSString *path) {
    NSData *bytes = [path.stringByStandardizingPath dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *hex = [NSMutableString stringWithCapacity:sizeof(digest) * 2];
    for (NSUInteger index = 0; index < sizeof(digest); index++) [hex appendFormat:@"%02x", digest[index]];
    return hex;
}
