#import "Canvas.h"
NSArray<NSDictionary *> *DPEaselMergeGesture(NSArray<NSDictionary *> *base,NSArray<NSDictionary *> *edited,NSArray<NSDictionary *> *current,BOOL *conflict) {
    if(conflict) *conflict=NO;
    if(!base || [base isEqual:current]) return edited;
    NSMutableDictionary *old=NSMutableDictionary.new,*next=NSMutableDictionary.new,*latest=NSMutableDictionary.new;
    for(NSDictionary *object in base) old[object[@"id"]]=object;
    for(NSDictionary *object in edited) next[object[@"id"]]=object;
    for(NSDictionary *object in current) latest[object[@"id"]]=object;
    NSMutableSet *changed=NSMutableSet.new;
    for(NSString *identifier in old) if(![old[identifier] isEqual:next[identifier]]) [changed addObject:identifier];
    for(NSString *identifier in next) if(!old[identifier]) [changed addObject:identifier];
    for(NSString *identifier in changed) {
        BOOL unchanged=old[identifier] ? [latest[identifier] isEqual:old[identifier]] : latest[identifier]==nil;
        BOOL sameResult=next[identifier] ? [latest[identifier] isEqual:next[identifier]] : latest[identifier]==nil;
        if(!unchanged && !sameResult) {
            // Cancel the whole group gesture rather than moving half a selection
            // or overwriting an object another placement changed or deleted.
            if(conflict) *conflict=YES; return current;
        }
    }
    NSMutableArray *result=NSMutableArray.new;
    for(NSDictionary *object in current) {
        NSString *identifier=object[@"id"];
        if(![changed containsObject:identifier]) [result addObject:object];
        else if(next[identifier]) [result addObject:next[identifier]];
    }
    NSUInteger order=0; double z=0;
    for(NSDictionary *object in current) { order=MAX(order,[object[@"order"] unsignedIntegerValue]); z=MAX(z,[object[@"z"] doubleValue]); }
    for(NSDictionary *object in edited) if(!latest[object[@"id"]] && !old[object[@"id"]]) {
        // A draft has not published its creation order yet. Reserve fresh order
        // and layer values after additions committed by another placement.
        if(object[@"order"]) {
            NSMutableDictionary *added=[object mutableCopy];
            order=MAX(order+1,[object[@"order"] unsignedIntegerValue]); z=MAX(z+1,[object[@"z"] doubleValue]);
            added[@"order"]=@(order); added[@"z"]=@(z); [result addObject:added];
        } else [result addObject:object];
    }
    return result;
}
