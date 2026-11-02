// Exercise the actual CDP stream reader and origin wait against delayed/redirected navigation.
#import "../src/diapatch/Passkeys.m"
static void reply(FILE *stream, int id, NSArray *state) {
    NSDictionary *message = @{ @"id": @(id), @"result": @{ @"result": @{ @"value": state } } };
    NSData *data = [NSJSONSerialization dataWithJSONObject:message options:0 error:nil];
    fwrite(data.bytes, 1, data.length, stream); fputc(0, stream); fflush(stream);
}
int main(void) { @autoreleasepool {
    // Preloaded CDP replies are sufficient: Runtime.evaluate requests still go through the real writer.
    gToHelper = tmpfile(); gFromHelper = tmpfile();
    reply(gFromHelper, 1, @[ @"null", @"complete" ]);
    reply(gFromHelper, 2, @[ @"https://example.com", @"loading" ]);
    reply(gFromHelper, 3, @[ @"https://example.com", @"complete" ]);
    rewind(gFromHelper);
    NSCAssert(atOrigin(@"session", @"https://example.com"), @"wait past the old completed page and the new loading page");
    fclose(gFromHelper); gFromHelper = tmpfile();
    for (int i = 4; i < 54; i++) reply(gFromHelper, i, @[ @"https://other.example", @"complete" ]);
    rewind(gFromHelper);
    NSCAssert(!atOrigin(@"session", @"https://example.com"), @"a redirect must not authenticate at the wrong origin");
    fclose(gFromHelper); fclose(gToHelper);
    puts("ok: delayed navigation, loading document and cross-origin redirect");
} }
