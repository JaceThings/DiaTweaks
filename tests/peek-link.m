#import "Patches/Peek/Peek.h"

static int failures;

static void expect(BOOL ok, NSString *what) {
    if (ok) return;
    failures++;
    printf("FAIL %s\n", what.UTF8String);
}

// The URL Dia navigates to for a click, and the text Dia's status line shows for the same link.
static void same(NSString *clicked, NSString *shown) {
    expect([DPPeekLinkKey(clicked) isEqual:DPPeekLinkKey(shown)], [NSString stringWithFormat:@"%@ should match %@", clicked, shown]);
}

static void differ(NSString *one, NSString *other) {
    expect(![DPPeekLinkKey(one) isEqual:DPPeekLinkKey(other)], [NSString stringWithFormat:@"%@ should not match %@", one, other]);
}

int main(void) {
    @autoreleasepool {
        same(@"http://127.0.0.1:8470/x.html?same-blank", @"127.0.0.1:8470/x.html?same-blank");
        same(@"https://example.com/a/b?c=d", @"https://example.com/a/b?c=d");
        same(@"https://example.com/", @"example.com");
        same(@"https://example.com/a/", @"example.com/a/");
        same(@"https://example.com/a%20b", @"example.com/a b");
        same(@"https://example.com/?q=a%20b", @"example.com/?q=a b");
        same(@"https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC%E8%AA%9E", @"ja.wikipedia.org/wiki/日本語");
        same(@"https://ja.wikipedia.org/wiki/%E6%97%A5%E6%9C%AC%E8%AA%9E", @"https://ja.wikipedia.org/wiki/日本語");
        same(@"https://example.com/s?q=caf%C3%A9&n=1%2B1", @"example.com/s?q=café&n=1%2B1");
        same(@"https://example.com/a%25b", @"example.com/a%25b");
        same(@"https://example.com/p#a%20b", @"example.com/p#a b");
        same(@"https://xn--mnchen-3ya.de/%C3%BC", @"münchen.de/ü");
        same(@"https://xn--wgv71a119e.jp/", @"日本語.jp");

        differ(@"https://example.com/a", @"example.com/b");
        differ(@"https://example.com/a%20b", @"example.com/a_b");
        differ(@"https://example.com/a%2Fb", @"example.com/a/b");
        differ(@"https://example.com/a/b", @"example.com/a");
        differ(@"https://example.com/a?b", @"example.com/a");
        differ(@"https://example.com/a#b", @"example.com/a");
        differ(@"https://ja.wikipedia.org/wiki/%E6%97%A5", @"ja.wikipedia.org/wiki/%E6%9C%AC");
        differ(@"https://example.com/s?q=caf%C3%A9", @"example.com/s?q=cafe");
        differ(@"https://xn--mnchen-3ya.de/", @"munchen.de");
    }
    if (failures) printf("%d failures\n", failures);
    else printf("peek links ok\n");
    return failures ? 1 : 0;
}
