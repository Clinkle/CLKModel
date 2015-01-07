#import "KeychainItemWrapper.h"

@interface KeychainItemWrapper ()

@end

@implementation KeychainItemWrapper

+ (NSString *)defaultService
{
    return [[NSBundle mainBundle] bundleIdentifier];
}

+ (NSString *)stringForKey:(NSString *)key
{
    NSString *value = [self stringForKey:key
                                 service:nil
                                 account:nil
                             accessGroup:nil];
    if (!value) {
        // backward compatibility with the old KeychainItemWrapper
        value = [KeychainItemWrapper stringForKey:key
                                          service:key
                                          account:@""
                                      accessGroup:nil];
    }
    return value;
}

+ (NSString *)stringForKey:(NSString *)key
                   service:(NSString *)service
                   account:(NSString *)account
               accessGroup:(NSString *)accessGroup
{
    if (!key) {
        return nil;
    }
    if (!service) {
        service = [self defaultService];
    }
    if (!account) {
        account = key;
    }
    
    NSMutableDictionary *query = [@{ (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                     (__bridge id)kSecReturnData: (__bridge id)kCFBooleanTrue,
                                     (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne,
                                     (__bridge id)kSecAttrService: service,
                                     (__bridge id)kSecAttrGeneric: key,
                                     (__bridge id)kSecAttrAccount: account
                                     } mutableCopy];
#if !TARGET_IPHONE_SIMULATOR && defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    if (accessGroup) {
        [query setObject:accessGroup
                  forKey:(__bridge id)kSecAttrAccessGroup];
    }
#endif
    
    CFTypeRef keyData = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &keyData);
    if (status != errSecSuccess) {
        return nil;
    }
    
    NSData *data = [NSData dataWithData:(__bridge NSData *)keyData];
    NSString *value = [[NSString alloc] initWithBytes:[data bytes]
                                               length:[data length]
                                             encoding:NSUTF8StringEncoding];
    
    if (keyData) {
        CFRelease(keyData);
    }
    
    return value;
}

+ (BOOL)setData:(NSData *)data
         forKey:(NSString *)key
{
    return [self setData:data
                  forKey:key
                 service:nil
             accessGroup:nil];
}

+ (BOOL)setData:(NSData *)data
         forKey:(NSString *)key
        service:(NSString *)service
    accessGroup:(NSString *)accessGroup
{
    if (!key) {
        return NO;
    }
    if (!service) {
        service = [self defaultService];
    }
    
    NSMutableDictionary *query = [@{
                                    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                    (__bridge id)kSecAttrService: service,
                                    (__bridge id)kSecAttrGeneric: key,
                                    (__bridge id)kSecAttrAccount: key
                                    } mutableCopy];
#if !TARGET_IPHONE_SIMULATOR && defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    if (accessGroup) {
        [query setObject:accessGroup
                  forKey:(__bridge id)kSecAttrAccessGroup];
    }
#endif
    
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
    if (status == errSecSuccess) {
        if (data) {
            NSMutableDictionary *attributesToUpdate = [[NSMutableDictionary alloc] init];
            [attributesToUpdate setObject:data
                                   forKey:(__bridge id)kSecValueData];
            
            status = SecItemUpdate((__bridge CFDictionaryRef)query,
                                   (__bridge CFDictionaryRef)attributesToUpdate);
            if (status != errSecSuccess) {
                NSAssert( status == errSecSuccess, @"Couldn't add the Keychain Item. SecItemUpdate failed." );
                return NO;
            }
        } else {
            [self removeItemForKey:key
                           service:service
                       accessGroup:accessGroup];
        }
    } else if (status == errSecItemNotFound) {
        if (!data) {
            return YES;
        }
        NSMutableDictionary *attributes = [@{
                                             (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                             (__bridge id)kSecAttrService: service,
                                             (__bridge id)kSecAttrGeneric: key,
                                             (__bridge id)kSecAttrAccount: key
                                             } mutableCopy];
#if TARGET_OS_IPHONE || (defined(MAC_OS_X_VERSION_10_9) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_9)
        [attributes setObject:(__bridge id)kSecAttrAccessibleAfterFirstUnlock
                       forKey:(__bridge id)kSecAttrAccessible];
#endif
        [attributes setObject:data
                       forKey:(__bridge id)kSecValueData];
#if !TARGET_IPHONE_SIMULATOR && defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
        if (accessGroup) {
            [attributes setObject:accessGroup
                           forKey:(__bridge id)kSecAttrAccessGroup];
        }
#endif
        
        status = SecItemAdd((__bridge CFDictionaryRef)attributes, NULL);
        if (status != errSecSuccess) {
            NSAssert( status == errSecSuccess, @"Couldn't add the Keychain Item. SecItemAdd failed." );
            return NO;
        }
    } else {
        NSAssert( status == errSecSuccess, @"Couldn't add the Keychain Item. SecItemCopyMatching failed" );
        return NO;
    }
    
    return YES;
}

#pragma mark -

+ (BOOL)removeItemForKey:(NSString *)key
{
    return [self removeItemForKey:key
                          service:nil
                      accessGroup:nil];
}

+ (BOOL)removeItemForKey:(NSString *)key
                 service:(NSString *)service
             accessGroup:(NSString *)accessGroup
{
    if (!key) {
        return NO;
    }
    if (!service) {
        service = [self defaultService];
    }
    
    NSMutableDictionary *itemToDelete = [@{
                                           (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
                                           (__bridge id)kSecAttrService: service,
                                           (__bridge id)kSecAttrGeneric: key,
                                           (__bridge id)kSecAttrAccount: key
                                           } mutableCopy];
#if !TARGET_IPHONE_SIMULATOR && defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    if (accessGroup) {
        [itemToDelete setObject:accessGroup
                         forKey:(__bridge id)kSecAttrAccessGroup];
    }
#endif
    
    OSStatus status = SecItemDelete((__bridge CFDictionaryRef)itemToDelete);
    if (status != errSecSuccess && status != errSecItemNotFound) {
        return NO;
    }
    
    return YES;
}

+ (NSArray *)itemsForService:(NSString *)service
                 accessGroup:(NSString *)accessGroup
{
    if (!service) {
        service = [self defaultService];
    }
    
    NSMutableDictionary *query = [[NSMutableDictionary alloc] init];
    [query setObject:(__bridge id)kSecClassGenericPassword
              forKey:(__bridge id)kSecClass];
    [query setObject:(id)kCFBooleanTrue
              forKey:(__bridge id)kSecReturnAttributes];
    [query setObject:(id)kCFBooleanTrue
              forKey:(__bridge id)kSecReturnData];
    [query setObject:(__bridge id)kSecMatchLimitAll
              forKey:(__bridge id)kSecMatchLimit];
    [query setObject:service
              forKey:(__bridge id)kSecAttrService];
#if !TARGET_IPHONE_SIMULATOR && defined(__IPHONE_OS_VERSION_MIN_REQUIRED)
    if (accessGroup) {
        [query setObject:accessGroup
                  forKey:(__bridge id)kSecAttrAccessGroup];
    }
#endif
    
    CFArrayRef result = nil;
    OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&result);
    if (status == errSecSuccess || status == errSecItemNotFound) {
        return CFBridgingRelease(result);
    } else {
        return nil;
    }
}

+ (BOOL)removeAllItems
{
    return [self removeAllItemsForService:nil accessGroup:nil];
}

+ (BOOL)removeAllItemsForService:(NSString *)service
                     accessGroup:(NSString *)accessGroup
{
    NSArray *items = [KeychainItemWrapper itemsForService:service
                                              accessGroup:accessGroup];
    for (NSDictionary *item in items) {
        NSMutableDictionary *itemToDelete = [[NSMutableDictionary alloc] initWithDictionary:item];
        [itemToDelete setObject:(__bridge id)kSecClassGenericPassword
                         forKey:(__bridge id)kSecClass];
        
        OSStatus status = SecItemDelete((__bridge CFDictionaryRef)itemToDelete);
        if (status != errSecSuccess) {
            return NO;
        }
    }
    
    return YES;
}

@end
