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
    return [@{(__bridge id)kSecClass            : (__bridge id)kSecClassGenericPassword,
              (__bridge id)kSecAttrService      : key,
              (__bridge id)kSecAttrAccount      : key,
              (__bridge id)kSecAttrAccessible   : (__bridge id)kSecAttrAccessibleAfterFirstUnlock
              } mutableCopy];
}

+ (BOOL)saveKeychainValue:(id)value
                   forKey:(NSString*)key
{
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:key];
    if (!keychainQuery) {
        return NO;
    }

    [self deleteKeychainValueForKey:key];
    
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:value]
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
        value = [NSKeyedUnarchiver unarchiveObjectWithData:(__bridge NSData *)keyData];
    }
    
    if (keyData) {
        CFRelease(keyData);
    }
    
    return value;
}

@end
