#import "BriefLanguage.h"

// The dylib reads this heading back to see which language the installed Dia writes in: keep the two in step.
static NSString *const DPBriefHeading = @"## Output language: ";
static NSString *const DPBriefPrompt = @"Contents/Resources/agent-server-resources/dist/prompts/skills/morning-brief/SKILL.md";

// The choice goes into a prompt, so only a plain language name gets through.
static NSString *DPChosenLanguage(void) {
    // DIATWEAKS_DOMAIN lets a test build read settings of its own, as it does for diatweaks.
    NS_VALID_UNTIL_END_OF_SCOPE NSString *name = @(getenv("DIATWEAKS_DOMAIN") ?: "com.diapatches");
    CFStringRef domain = (__bridge CFStringRef)name;
    CFPreferencesAppSynchronize(domain);
    if (!CFPreferencesGetAppBooleanValue(CFSTR("briefLanguage"), domain, NULL)) return nil;
    NSString *language = CFBridgingRelease(CFPreferencesCopyAppValue(CFSTR("briefLanguageChoice"), domain));
    if (![language isKindOfClass:NSString.class]) return nil;
    NSCharacterSet *other = [NSCharacterSet characterSetWithCharactersInString:@"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz ()"].invertedSet;
    return language.length && language.length <= 40 && [language rangeOfCharacterFromSet:other].location == NSNotFound ? language : nil;
}

NSString *DPPrepareBriefLanguage(NSString *app) {
    NSString *language = DPChosenLanguage();
    if (!language) return nil;
    NSString *path = [app stringByAppendingPathComponent:DPBriefPrompt];
    NSString *prompt = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (!prompt) return @"kept the Morning Brief's language: this Dia has no brief prompt";
    NSString *rule = [NSString stringWithFormat:
        @"\n\n%@%@\n"
        @"Write every piece of text the user reads in %@: titles, bodies, labels, notes, blurbs, greetings, and each cta_label and cta_prompt. "
        @"This overrides the language of the examples above and of the sources you read. "
        @"Keep the field names, source_name, label_style, URLs and date formats exactly as specified, and keep names of people, companies, products, "
        @"channels and files as they are written in the source. Quote a source in its own language only when the exact wording matters.\n",
        DPBriefHeading, language, language];
    return [[prompt stringByAppendingString:rule] writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:NULL]
        ? [@"set the Morning Brief's language to " stringByAppendingString:language]
        : @"kept the Morning Brief's language: couldn't write the brief prompt";
}
