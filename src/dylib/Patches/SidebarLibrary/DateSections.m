#import "Library.h"
NSArray *DPLibraryDateSections(NSArray<DPLibraryFile *> *files,NSDate *now) {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *today = [calendar startOfDayForDate:now];
    NSDate *yesterday = [calendar dateByAddingUnit:NSCalendarUnitDay value:-1 toDate:today options:0];
    NSMutableArray *rows = [NSMutableArray new]; NSString *previous = nil;
    for (DPLibraryFile *file in files) {
        NSString *group = [file.date compare:today] != NSOrderedAscending ? @"Today" :
            ([file.date compare:yesterday] != NSOrderedAscending ? @"Yesterday" :
                [NSDateFormatter localizedStringFromDate:file.date dateStyle:NSDateFormatterLongStyle timeStyle:NSDateFormatterNoStyle]);
        if (![group isEqual:previous]) { [rows addObject:group]; previous = group; }
        [rows addObject:file];
    }
    return rows;
}
