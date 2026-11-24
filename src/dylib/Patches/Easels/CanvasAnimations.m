#import "Canvas.h"
#import "Animation.h"
#import "Patches/SidebarLibrary/MotionClock.h"
#import <float.h>
@implementation DPEaselCanvas (Animations)
- (void)stopImageAnimations { [self.animationClock stop]; self.animationClock=nil; [self.players removeAllObjects]; }
- (void)animateVisibleImages {
    if(!self.window || self.hiddenOrHasHiddenAncestor || !(self.window.occlusionState&NSWindowOcclusionStateVisible)) { [self stopImageAnimations]; return; }
    NSMutableArray *visible=NSMutableArray.new; NSMutableSet *active=NSMutableSet.new;
    for(NSDictionary *object in self.document.objects) if([object[@"animated"] boolValue] && ![self.staticAssets containsObject:object[@"asset"]] && NSIntersectsRect(DPEaselObjectRect(object),self.visibleRect)) {
        [visible addObject:object]; [active addObject:object[@"asset"]];
    }
    if(!visible.count) { [self stopImageAnimations]; return; }
    if(!self.players) self.players=NSMutableDictionary.new;
    for(NSString *asset in self.players.allKeys) if(![active containsObject:asset]) [self.players removeObjectForKey:asset];
    if(!self.animationClock) {
        self.animationClock=DPLibraryMotionClock.new; __weak DPEaselCanvas *weak=self;
        self.animationClock.frame=^{ [weak animateVisibleImages]; }; [self.animationClock startForWindow:self.window];
    }
    NSUInteger start=self.animationCursor++%visible.count;
    for(NSUInteger offset=0;offset<visible.count;offset++) {
        NSDictionary *object=visible[(start+offset)%visible.count]; NSString *asset=object[@"asset"];
        DPEaselFrameSource *player=self.players[asset];
        if(!player) { player=DPEaselFrameSource.new; player.url=[DPEaselStore.shared assetURL:asset document:self.document.identifier]; self.players[asset]=player; }
        if(player.pending || player.due>CACurrentMediaTime()) continue;
        __weak DPEaselCanvas *weak=self; __weak DPEaselFrameSource *weakPlayer=player;
        BOOL accepted=[player request:player.index completion:^(NSImage *image,NSTimeInterval delay,NSUInteger count){
            DPEaselCanvas *canvas=weak; DPEaselFrameSource *source=weakPlayer;
            source.pending=NO; source.due=CACurrentMediaTime()+delay;
            if(!canvas || !source || canvas.document.deleted || canvas.players[asset]!=source) return;
            if(count>1) source.index=(source.index+1)%count; else { source.due=DBL_MAX; [canvas.staticAssets addObject:asset]; }
            if(image) [canvas.images setObject:image forKey:asset cost:(NSUInteger)(image.size.width*image.size.height*4)];
            [canvas setNeedsDisplayInRect:DPEaselObjectRect(object)];
        }];
        if(accepted) player.pending=YES;
    }
}
@end
