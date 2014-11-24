#import "NSString+CLKPropertyFormats.h"

@implementation NSString (CLKPropertyFormats)

- (NSString *)camelCaseFromSnakeCase
{
    NSMutableString *output = [NSMutableString string];
    BOOL makeNextCharacterUpperCase = NO;
    for (NSInteger idx = 0; idx < [self length]; idx += 1) {
        unichar c = [self characterAtIndex:idx];
        if (c == '_') {
            makeNextCharacterUpperCase = YES;
        } else if (makeNextCharacterUpperCase) {
            [output appendString:[[NSString stringWithCharacters:&c
                                                          length:1] uppercaseString]];
            makeNextCharacterUpperCase = NO;
        } else {
            [output appendFormat:@"%C",
             c];
        }
    }
    return output;
}

- (NSString *)camelCasePrependWord:(NSString *)prefix
{
    NSString *firstChar = [self substringToIndex:1];
    NSString *suffix = [self substringFromIndex:1];
    NSString *camelCase = [NSString stringWithFormat:@"%@%@%@",
                           prefix,
                           firstChar.uppercaseString,
                           suffix];
    return camelCase;
}

- (NSString *)snakeCaseFromCamelCase
{
    return [self separateCamelCaseAsSnakeCase:YES];
}

- (NSString *)separateWordsFromCamelCase
{
    NSMutableArray *words = [[[self separateCamelCaseAsSnakeCase:NO] componentsSeparatedByString:@" "] mutableCopy];
    if (words.count > 0) {
        words[0] = [words[0] capitalizedString];
    }
    return [words componentsJoinedByString:@" "];
}

- (NSString *)separateCamelCaseAsSnakeCase:(BOOL)snakeCase
{
    NSMutableString *output = [NSMutableString string];
    NSCharacterSet *uppercase = [NSCharacterSet uppercaseLetterCharacterSet];
    NSMutableString *uppercaseCharsInARow = [NSMutableString string];
    for (NSInteger idx = 0; idx < [self length]; idx += 1) {
        unichar c = [self characterAtIndex:idx];
        if ([uppercase characterIsMember:c]) {
            [uppercaseCharsInARow appendFormat:@"%C", c];
        } else {
            if (uppercaseCharsInARow.length > 0) {
                NSInteger indexOfLast = uppercaseCharsInARow.length - 1;
                NSString *exceptLast = [uppercaseCharsInARow substringToIndex:indexOfLast];
                NSString *last = [uppercaseCharsInARow substringFromIndex:indexOfLast];
                if (snakeCase) {
                    [output appendFormat:@"%@_%@",
                     [exceptLast lowercaseString],
                     [last lowercaseString]];
                } else {
                    [output appendFormat:@"%@ %@",
                     exceptLast,
                     last];
                }
                uppercaseCharsInARow = [NSMutableString string];
            }
            [output appendFormat:@"%C", c];
        }
    }
    if (uppercaseCharsInARow.length > 0) {
        if (snakeCase) {
            [output appendFormat:@"_%@",
             [uppercaseCharsInARow lowercaseString]];
        } else {
            [output appendFormat:@" %@", uppercaseCharsInARow];
        }
    }
    return output;
}

@end
