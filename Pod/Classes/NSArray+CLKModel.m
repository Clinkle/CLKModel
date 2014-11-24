#import "NSArray+CLKModel.h"
#import "CLKModel.h"

@implementation NSArray (CLKModel)

- (NSMutableArray *)clk_toJSON
{
    NSMutableArray *toJSONs = [NSMutableArray arrayWithCapacity:[self count]];
    for (CLKModel *model in self) {
        if (![model isKindOfClass:[CLKModel class]]) {
            return nil;
        }
        NSDictionary *json = [model toJSON];
        if (json) {
            [toJSONs addObject:json];
        }
    }
    return toJSONs;
}

- (NSMutableArray *)clk_modelCopy
{
    NSMutableArray *modelCopies = [NSMutableArray arrayWithCapacity:[self count]];
    for (CLKModel *model in self) {
        if (![model isKindOfClass:[CLKModel class]]) {
            return nil;
        }
        CLKModel *copy = [model modelCopy];
        if (copy) {
            [modelCopies addObject:copy];
        }
    }
    return modelCopies;
}

@end
