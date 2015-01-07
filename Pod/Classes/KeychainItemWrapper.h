#import <Foundation/Foundation.h>

@interface KeychainItemWrapper : NSObject

+ (NSString *)stringForKey:(NSString *)key;
+ (BOOL)setData:(NSData *)data
         forKey:(NSString *)key;
+ (BOOL)removeItemForKey:(NSString *)key;
+ (BOOL)removeAllItems;

@end
