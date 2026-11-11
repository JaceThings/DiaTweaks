#import "Patches/TidyNames/Names.h"
#import "Patches/TidyNames/DownloadBridge.h"

static void CheckDownloadManifest(void) {
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    NSString *helper = @"/test/DiaPatches/bin/diapatch";
    NSMutableDictionary *manifest = [@{
        @"name": DPTidyDownloadHost,
        @"path": helper,
        @"allowed_origins": @[@DPTidyDownloadExtensionOrigin],
    } mutableCopy];
    NSCAssert(!DPTidyDownloadManifestOwned(path, helper), @"A missing host is not owned");
    NSData *data = [NSJSONSerialization dataWithJSONObject:manifest options:0 error:nil];
    NSCAssert([data writeToFile:path atomically:YES], @"Write a disposable manifest");
    NSCAssert(DPTidyDownloadManifestOwned(path, helper), @"Recognize this installation's host");
    NSCAssert(!DPTidyDownloadManifestOwned(path, @"/other/install/diapatch"), @"Preserve other installations");
    manifest[@"allowed_origins"] = @[];
    data = [NSJSONSerialization dataWithJSONObject:manifest options:0 error:nil];
    NSCAssert([data writeToFile:path atomically:YES], @"Write a changed origin");
    NSCAssert(!DPTidyDownloadManifestOwned(path, helper), @"Preserve hosts with a different origin");
    [NSFileManager.defaultManager removeItemAtPath:path error:nil];
}

int main(void) {
    @autoreleasepool {
        for (NSString *name in @[@"pdf-sample_0.pdf", @"file-sample_100kB.doc", @"_ (1).jpeg", @"839494875.pdf", @"IMG_1234.JPG", @"download (2).zip",
                                 @"550e8400-e29b-41d4-a716-446655440000.pdf", @"a10bf412007cffee.txt", @"p7x91b4v9z12.pdf"])
            NSCAssert(DPTidyDownloadNeedsRename(name), @"Expected opaque name: %@", name);
        for (NSString *name in @[@"Navan Itinerary.pdf", @"Invoice 38349075.pdf", @"Quarterly-report.xlsx"])
            NSCAssert(!DPTidyDownloadNeedsRename(name), @"Expected useful name: %@", name);
        NSCAssert([DPTidyValidatedFilename(@"  Navan Itinerary.pdf ", @"839494875.PDF")
            isEqualToString:@"Navan Itinerary.PDF"], @"Preserve the original extension");
        for (NSString *name in @[@"SKIP", @"../Navan Itinerary", @"New Name.exe", @"download 23", @"A/B report"])
            NSCAssert(!DPTidyValidatedFilename(name, @"839494875.pdf"), @"Reject unsuitable output: %@", name);
        NSCAssert(DPTidyFilenameMatchesSuggestion(@"Navan Itinerary (2).pdf", @"Navan Itinerary.pdf"),
            @"Use the collision-safe name Chromium actually saved");
        NSCAssert(!DPTidyFilenameMatchesSuggestion(@"Navan Itinerary (Final).pdf", @"Navan Itinerary.pdf"),
            @"Leave user-edited names alone");
        NSCAssert(!DPTidyTitleNeedsRename(@"Interior Design Book"), @"Keep a useful short title");
        NSCAssert(DPTidyTitleNeedsRename(@"The Complete Interior Design Source Book"), @"Consider long page titles");
        NSCAssert([DPTidyValidatedTitle(@" Interior   Design Book ", @"The Complete Interior Design Source Book")
            isEqualToString:@"Interior Design Book"], @"Normalize the proposed title");
        NSCAssert(!DPTidyValidatedTitle(@"SKIP", @"A longer title"), @"Respect the model's abstention");
        NSCAssert(!DPTidyValidatedTitle(@"Family Another", @"Another Family | Members"),
            @"Never let the model reverse a brand");
        NSCAssert([DPTidySectionTitle(@"Members | Another Family", [NSURL URLWithString:@"https://anotherfamily.example/members"])
            isEqualToString:@"Another Family Members"], @"Keep the brand and identify the section");
        NSCAssert([DPTidySectionTitle(@"Example Community", [NSURL URLWithString:@"https://community.example/members"])
            isEqualToString:@"Example Community Members"], @"Use a meaningful route when the title contains only the brand");
        NSCAssert([DPTidyFallbackTitle(@"The Lisbon Walking Tours and Historic Neighborhoods Guide | Travel")
            isEqualToString:@"Lisbon Walking Tours"], @"Use the page title if the model is unavailable");
        NSCAssert(!DPTidyFallbackTitle(@"404 | Example Site"), @"Avoid making up a title for an error page");
        NSString *source = DPTidyNameSource([NSURL URLWithString:@"https://user:password@example.com/trips/lisbon?token=secret#private"]);
        NSCAssert([source isEqualToString:@"example.com/trips/lisbon"], @"Strip credentials, query and fragment");
        NSCAssert(!DPTidyNameSource([NSURL URLWithString:@"file:///Users/test/private.pdf"]).length, @"Skip file URLs");
        NSCAssert([DPTidyFallbackFilename([NSURL URLWithString:@"https://example.com/trips/lisbon/itinerary"], @"839494875.pdf")
            isEqualToString:@"Lisbon Itinerary.pdf"], @"Use descriptive URL segments if the model times out");
        NSCAssert(!DPTidyFallbackFilename([NSURL URLWithString:@"https://example.com/api/download/839494875.pdf"], @"839494875.pdf"),
            @"Do not invent a title from an opaque URL");
        NSCAssert([DPTidyImageFilename([NSURL URLWithString:@"blob:https://in.pinterest.com/9b843"], @"_.jpeg")
            isEqualToString:@"Pinterest Image.jpeg"], @"Name a Pinterest blob even without a referrer");
        NSCAssert([DPTidyImageFilename([NSURL URLWithString:@"https://i.pinimg.com/originals/000.jpg"], @"_ (3).jpeg")
            isEqualToString:@"Pinimg Image.jpeg"], @"Use the source domain when there is no referring site");
        NSCAssert(!DPTidyImageFilename([NSURL URLWithString:@"https://pinterest.com"], @"My Cat.jpeg"),
            @"Keep an existing descriptive image name");
        NSString *wikimedia = @"Verdun_–_Cathe\u0301drale_Notre-Dame_–_Crypte_2025_08_16.jpg.webp";
        NSCAssert(DPTidyDownloadNeedsRename(wikimedia) &&
            [DPTidyCleanImageFilename(wikimedia) isEqualToString:@"Verdun – Cathédrale Notre-Dame – Crypte.webp"],
            @"Keep the credited subject, accents and actual saved extension");
        NSCAssert(!DPTidyCleanImageFilename(@"IMG_1234.JPG"), @"An image counter is not a subject");
        NSCAssert([DPTidyImageFilename([NSURL URLWithString:@"https://medlineplus.gov/encyclopedia.html"], @"m_logo.png")
            isEqualToString:@"Medlineplus Logo.png"], @"Keep logo as the role and use the site name as a fallback");
        NSCAssert([DPTidyImageFilename([NSURL URLWithString:@"https://example.net/"], @"_.avif")
            isEqualToString:@"Example Image.avif"], @"Use the same rule for an opaque image from another site");
        NSCAssert([DPTidyImageFilename([NSURL URLWithString:@"https://www.new-site.co.uk/assets"], @"logo.png")
            isEqualToString:@"New Site Logo.png"], @"Handle an unfamiliar hyphenated domain and country suffix");
        NSCAssert([DPTidyFallbackFilename([NSURL URLWithString:@"https://example.com/media/sunset-over-lisbon.jpg"], @"_.jpeg")
            isEqualToString:@"Sunset Over Lisbon.jpeg"], @"Use the subject from the URL and preserve the saved extension");
        CheckDownloadManifest();
        puts("PASS: filename and title validation, URL redaction, and download host ownership");
    }
}
