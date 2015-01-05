#import "KeychainItemWrapper.h"

@interface KeychainItemWrapper ()

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key;

@end

@implementation KeychainItemWrapper

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)key
{
    if (!key) {
        return nil;
    }
    /* the keychain requires kSecAttrGeneric AND kSecAttrService to make the entry unique */
    return [@{(__bridge id)kSecClass            : (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrGeneric      : key,
              (__bridge id)kSecAttrService      : key,
              } mutableCopy];
}

+ (BOOL)saveKeychainValue:(id)value
                   forKey:(NSString*)key
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    if (!keychainQuery) {
        return NO;
    }

    BOOL didDelete = [self deleteKeychainValueForKey:key];
    if (!didDelete) {
        // TODO ??
    }

    if (!value) {
        return NO;
    }

    if ([value isKindOfClass:[NSString class]]) {
        value = [value dataUsingEncoding:NSUTF8StringEncoding];
    }
    [keychainQuery setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock
                      forKey:(__bridge id)kSecAttrAccessible];
    [keychainQuery setObject:value
                      forKey:(__bridge id)kSecValueData];
    
    OSStatus result = SecItemAdd((__bridge CFDictionaryRef)keychainQuery, NULL);
    NSAssert( result == noErr, @"Couldn't add the Keychain Item." );
    return (result == noErr);
}

+ (BOOL)deleteKeychainValueForKey:(NSString *)key
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    if (!keychainQuery) {
        return NO;
    }
    OSStatus result = SecItemDelete((__bridge CFDictionaryRef)keychainQuery);
    return (result == noErr);
}

+ (id)getKeychainValueForKey:(NSString *)key
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    if (!keychainQuery) {
        return nil;
    }

    id value = nil;
    CFDataRef keyData = NULL;
    
    [keychainQuery setObject:(__bridge id)kCFBooleanTrue
                      forKey:(__bridge id)kSecReturnData];
    [keychainQuery setObject:(__bridge id)kSecMatchLimitOne
                      forKey:(__bridge id)kSecMatchLimit];
    
    if (SecItemCopyMatching((__bridge CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        NSData *data = (__bridge NSData *)keyData;
        value = [[NSString alloc] initWithBytes:[data bytes]
                                         length:[data length]
                                       encoding:NSUTF8StringEncoding];
    }
    if (keyData) {
        CFRelease(keyData);
    }
    
    return value;
}

@end
