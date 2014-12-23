#import <Foundation/Foundation.h>

// A simplified keychain interface, with implementation details gathered from:
// http://developer.apple.com/library/ios/#DOCUMENTATION/Security/Reference/keychainservices/Reference/reference.html
// http://stackoverflow.com/questions/5247912 and https://github.com/jeremangnr/JNKeychain
@interface KeychainItemWrapper : NSObject

+ (BOOL)saveKeychainValue:(id)value 
                   forKey:(NSString*)key;
+ (BOOL)deleteKeychainValueForKey:(NSString *)key;
+ (id)getKeychainValueForKey:(NSString*)key;

@end
