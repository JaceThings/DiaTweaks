#import "Library.h"
NSNotificationName const DPLibrarySectionsChanged=@"DPLibrarySectionsChanged";
static NSMutableArray<id<DPLibrarySectionProvider>> *DPSectionProviders;
void DPLibraryRegisterSection(id<DPLibrarySectionProvider> provider) {
    if(!DPSectionProviders) DPSectionProviders=NSMutableArray.new;
    for(id<DPLibrarySectionProvider> existing in DPSectionProviders) if([existing.title isEqual:provider.title]) return;
    [DPSectionProviders addObject:provider];
    [DPSectionProviders sortUsingComparator:^NSComparisonResult(id<DPLibrarySectionProvider> a,id<DPLibrarySectionProvider> b){
        NSInteger left=[a respondsToSelector:@selector(sectionOrder)] ? a.sectionOrder : 500;
        NSInteger right=[b respondsToSelector:@selector(sectionOrder)] ? b.sectionOrder : 500;
        return left<right ? NSOrderedAscending : left>right ? NSOrderedDescending : [a.title compare:b.title];
    }];
}
static id<DPLibrarySectionProvider> DPProvider(NSString *title) {
    for(id<DPLibrarySectionProvider> provider in DPSectionProviders) if(provider.isEnabled && [provider.title isEqual:title]) return provider;
    return nil;
}
NSArray<NSString *> *DPLibrarySectionNames(void) {
    NSMutableArray *names=NSMutableArray.new;
    for(id<DPLibrarySectionProvider> provider in DPSectionProviders) if(provider.isEnabled) [names addObject:provider.title];
    [names addObjectsFromArray:@[@"Media",@"Downloads",@"Archived Tabs"]]; return names;
}
void DPLibraryBuildCategories(DPLibraryController *controller) {
    for(NSView *view in controller.rail.subviews.copy) if([view.identifier isEqual:@"category"]) [view removeFromSuperview];
    NSArray *names=DPLibrarySectionNames();
    if(![names containsObject:controller.section]) controller.section=@"Media";
    NSDictionary *symbols=@{@"Media":@"photo.on.rectangle",@"Downloads":@"arrow.down.circle",@"Archived Tabs":@"archivebox"};
    for(NSUInteger i=0;i<names.count;i++) {
        NSString *name=names[i];
        NSButton *button=DPLibraryMakeButton([name isEqual:@"Archived Tabs"] ? @"Archive" : name,symbols[name] ?: DPProvider(name).symbol,controller,@selector(chooseSection:));
        button.accessibilityLabel=name; button.toolTip=name; button.tag=i; button.identifier=@"category";
        button.state=[name isEqual:controller.section]; [controller.rail addSubview:button];
    }
    controller.layoutSignature=nil;
}
@implementation DPLibraryController (SectionActions)
- (void)primarySectionAction:(id)sender { [DPProvider(self.section) primaryAction:self]; }
@end
BOOL DPLibraryReloadCustomSection(DPLibraryController *controller) {
    id<DPLibrarySectionProvider> provider=DPProvider(controller.section);
    if(!provider) {
        controller.preferredSectionResponder=nil;
        for(NSView *button in controller.customHeaderButtons) [button removeFromSuperview]; controller.customHeaderButtons=nil;
        [controller.customContent removeFromSuperview]; controller.customContent=nil; controller.customSection=nil;
        controller.sectionAction.hidden=YES; controller.refresh.hidden=NO; controller.options.hidden=NO;
        return NO;
    }
    if(![controller.customSection isEqual:controller.section]) {
        controller.preferredSectionResponder=nil;
        for(NSView *button in controller.customHeaderButtons) [button removeFromSuperview]; controller.customHeaderButtons=nil;
        [controller.customContent removeFromSuperview]; controller.customContent=[provider makeContent:controller];
        controller.customSection=controller.section;
        // Give custom sections their own full-size backing surface before
        // translating Library. Ancestor visibleRects still describe native
        // sidebar geometry and must not trim the reveal's right edge.
        controller.customContent.wantsLayer=YES;
        [controller.view addSubview:controller.customContent];
        if([provider respondsToSelector:@selector(headerButtonsForContent:controller:)]) {
            controller.customHeaderButtons=[provider headerButtonsForContent:controller.customContent controller:controller];
            for(NSButton *button in controller.customHeaderButtons) { button.wantsLayer=YES; [controller.view addSubview:button]; }
        }
    }
    if(!controller.sectionAction) {
        controller.sectionAction=DPLibraryMakeButton(@"",@"plus",controller,@selector(primarySectionAction:));
        [controller.view addSubview:controller.sectionAction];
    }
    NSString *action=[provider respondsToSelector:@selector(primaryActionTitle)] ? provider.primaryActionTitle : [@"New " stringByAppendingString:provider.title];
    controller.sectionAction.accessibilityLabel=action; controller.sectionAction.toolTip=action;
    controller.sectionAction.hidden=!action.length; controller.refresh.hidden=YES; controller.options.hidden=YES;
    controller.scroll.hidden=YES; controller.mediaScroll.hidden=YES; controller.empty.hidden=YES; controller.filterChrome.hidden=YES;
    controller.search.placeholderString=[@"Search " stringByAppendingString:controller.section];
    [provider reloadContent:controller.customContent query:controller.search.stringValue];
    controller.layoutSignature=nil; [controller layout]; return YES;
}
void DPLibraryLayoutCustomSection(DPLibraryController *controller) {
    controller.customContent.frame=controller.scroll.frame;
    controller.sectionAction.frame=controller.options.frame;
    NSUInteger count=controller.customHeaderButtons.count;
    CGFloat right=controller.sectionAction.hidden ? NSMaxX(controller.options.frame) : NSMinX(controller.options.frame)-6;
    for(NSButton *button in controller.customHeaderButtons.reverseObjectEnumerator) {
        CGFloat width=[button.identifier isEqual:@"filterChip"] ? 122 : 30;
        button.frame=NSMakeRect(right-width,NSMinY(controller.options.frame)-3,width,36); right-=width+6;
    }
    if(count) {
        NSRect search=controller.searchChrome.frame;
        search.size.width=MAX(80,NSMinX(controller.customHeaderButtons.firstObject.frame)-8-NSMinX(search)); controller.searchChrome.frame=search;
        controller.search.frame=NSMakeRect(32,9,MAX(20,search.size.width-40),18);
    }
}
