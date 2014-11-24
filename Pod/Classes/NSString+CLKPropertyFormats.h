#import <Foundation/Foundation.h>

@interface NSString (CLKPropertyFormats)

- (NSString *)camelCaseFromSnakeCase;

- (NSString *)camelCasePrependWord:(NSString *)prefix;

- (NSString *)snakeCaseFromCamelCase;

- (NSString *)separateWordsFromCamelCase;

@end
