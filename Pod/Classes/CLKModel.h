#import <Foundation/Foundation.h>
#import "KeychainItemWrapper.h"
#import "NSString+CLKPropertyFormats.h"

@interface CLKModel : NSObject

#pragma mark - blueprint
+ (NSDictionary *)blueprint;
- (instancetype)initFromJSON:(NSDictionary *)json;
- (void)setFromJSON:(NSDictionary *)json;

#pragma mark - serialization
- (NSDictionary *)toJSON;
- (NSString *)toString;
- (instancetype)modelCopy;

#pragma mark - property storage
+ (id)legacyValueForProperty:(NSString *)property;
#pragma mark defaults
+ (NSArray *)defaultsBackedProperties;
+ (NSString *)defaultsKeyForProperty:(NSString *)property;
+ (id)defaultValueForProperty:(NSString *)property;
+ (void)resetDefaultsItems;
#pragma mark keychain
+ (NSArray *)keychainBackedProperties;
+ (NSString *)keychainNamespace;
+ (id)valueOfKeychainFor:(NSString *)property;
+ (void)resetKeychainItems;

#pragma mark temporary disk clearing house
+ (void)clearAllDefaults;
+ (void)clearAllKeychains;

@property (nonatomic, readonly) BOOL datesUseMillis;
@property (nonatomic, readonly) double dateConversionFactor;

@end
