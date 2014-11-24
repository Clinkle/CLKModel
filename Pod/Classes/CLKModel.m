#import "CLKModel.h"
#import <objc/runtime.h>
#import <ObjectiveSugar/NSArray+ObjectiveSugar.h>
#import <CLKUtilities/CLKUtilities.h>

/**
 This protocol exists to suppress compiler warnings.
 */
@protocol CLKModelOptionalSubclassMethods<NSObject>

@optional
+ (instancetype)singleton;
+ (BOOL)hasBeenCreated;

@end

@interface CLKModel ()<CLKModelOptionalSubclassMethods>

@property (nonatomic, strong) NSMutableDictionary *keychains;
@end

@implementation CLKModel

- (instancetype)init
{
    self = [super init];
    if (self) {
        [self initializeKeychainProperties];
        [self initializeDefaultsProperties];
    }
    return self;
}

- (instancetype)initFromJSON:(NSDictionary *)json
{
    self = [self init];
    if (self) {
        [self setFromJSON:json];
    }
    return self;
}

- (instancetype)initFromString:(NSString *)stringData
{
    NSData *data = [stringData dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *json = [NSPropertyListSerialization propertyListFromData:data
                                                          mutabilityOption:NSPropertyListImmutable
                                                                    format:nil
                                                          errorDescription:NULL];
    return [self initFromJSON:json];
}

- (void)dealloc
{
    [self cleanupKeychainObservers];
    [self cleanupDefaultsObservers];
}

#pragma mark - blueprint
+ (NSDictionary *)blueprint
{
    return @{};
}

#pragma mark - serializing
- (NSDictionary *)toJSON
{
    return [self toJSONWithBlueprint:self.class.blueprint];
}

- (NSDictionary *)toJSONWithBlueprint:(NSDictionary *)blueprint
{
    NSMutableDictionary *json = [NSMutableDictionary dictionaryWithCapacity:blueprint.count];
    for (NSString *key in blueprint) {
        id target = blueprint[key];
        id value = nil;
        if ([target isKindOfClass:[NSString class]]) {
            value = [self valueForKey:target];
            if ([value isKindOfClass:[CLKModel class]]) {
                value = [value toJSON];
            } else if ([value isKindOfClass:[NSDate class]]) {
                NSTimeInterval timeInterval = [value timeIntervalSince1970];
                timeInterval *= self.dateConversionFactor;
                value = @(timeInterval);
            } else {
                NSString *type = [self.class typeOfPropertyNamed:target];
                if ([type isEqualToString:@"BOOL"]) {
                    NSNumber *rawValue = (NSNumber *)value;
                    value = [NSNumber numberWithBool:rawValue.boolValue];
                }
            }
        } else if ([target isKindOfClass:[NSDictionary class]]) {
            if ([target[@"is_array"] boolValue]) {
                NSArray *models = (NSArray *)[self valueForKey:target[@"property"]];
                value = [NSMutableArray arrayWithCapacity:models.count];
                for (CLKModel *model in models) {
                    NSDictionary *modelAsJSON = [model toJSON];
                    if (modelAsJSON) {
                        [value addObject:modelAsJSON];
                    }
                }
            } else {
                value = [self toJSONWithBlueprint:target];
            }
        }
        if (value) {
            json[key] = value;
        }
    }
    return json;
}

- (NSString *)toString
{
    NSDictionary *json = [self toJSON];
    NSData *data = [NSPropertyListSerialization dataFromPropertyList:json
                                                              format:NSPropertyListXMLFormat_v1_0
                                                    errorDescription:NULL];
    return [[NSString alloc] initWithData:data
                                 encoding:NSUTF8StringEncoding];
}

- (instancetype)modelCopy
{
    NSDictionary *json = [self toJSON];
    return [[[self class] alloc] initFromJSON:json];
}

- (BOOL)datesUseMillis
{
    return YES;
}

- (double)dateConversionFactor
{
    return self.datesUseMillis ? 1000.0 : 1.0;
}

#pragma mark - deserializing
- (void)setFromJSON:(NSDictionary *)json
{
    [self setFromJSON:json
        withBlueprint:self.class.blueprint];
}

- (void)setFromJSON:(NSDictionary *)json
      withBlueprint:(NSDictionary *)blueprint
{
    for (NSString *key in json) {
        [self parseKey:key
                ofJSON:json
         withBlueprint:blueprint];
    }
}

- (void)parseKey:(NSString *)key
          ofJSON:(NSDictionary *)json
   withBlueprint:(NSDictionary *)blueprint
{
    id target = blueprint[key];
    id value = json[key];
    if ([target isKindOfClass:[NSString class]]) {
        [self assignValue:value
               toProperty:target];
    } else if ([target isKindOfClass:[NSDictionary class]]) {
        if ([target[@"is_array"] boolValue]) {
            NSArray *valuesAsJSON = (NSArray *)value;
            NSMutableArray *models = [NSMutableArray arrayWithCapacity:valuesAsJSON.count];
            Class clazz = NSClassFromString(target[@"class"]);
            for (NSDictionary *valueAsJSON in valuesAsJSON) {
                CLKModel *model = [[clazz alloc] initFromJSON:valueAsJSON];
                if (model) {
                    [models addObject:model];
                }
            }
            [self assignValue:models
                   toProperty:target[@"property"]];
        } else {
            [self setFromJSON:value
                withBlueprint:target];
        }
    }
}

- (void)assignValue:(id)value
         toProperty:(NSString *)property
{
    NSString *type = [self.class typeOfPropertyNamed:property];
    BOOL isPrimitive = [self.class typeIsPrimitive:type];
    if (isPrimitive) {
        value = value;
    } else if ([type isEqualToString:@"NSString"]) {
        value = value;
    } else if ([type isEqualToString:@"NSDate"]) {
        NSTimeInterval timeInterval = [value doubleValue];
        if (self.datesUseMillis) {
            timeInterval /= self.dateConversionFactor;
        }
        value = [NSDate dateWithTimeIntervalSince1970:timeInterval];
    } else {
        Class klass = NSClassFromString(type);
        if ([klass isSubclassOfClass:[CLKModel class]] &&
            [value isKindOfClass:[NSDictionary class]])
        {
            CLKModel *model = (CLKModel *)[klass alloc];
            value = [model initFromJSON:value];
        }
    }
    if (value && property && [self respondsToSelector:NSSelectorFromString(property)]) {
        [self setValue:value
                forKey:property];
    }
}

#pragma mark - property storage
+ (NSArray *)propertyNames
{
    unsigned int count = 0;
    objc_property_t *properties = class_copyPropertyList(self, &count);

    NSMutableArray *propertyNames = [NSMutableArray arrayWithCapacity:count];
    for (int i = 0; i < count; i++) {
        const char *propertyName = property_getName(properties[i]);
        if (propertyName) {
            NSString *propertyString = [NSString stringWithCString:propertyName
                                                          encoding:[NSString defaultCStringEncoding]];
            if (propertyString) {
                [propertyNames addObject:propertyString];
            }
        }
    }
    free(properties);
    return propertyNames;
}

+ (NSString *)genericTypeOfPropertyNamed:(NSString *)name
{
    return self.class.genericTypesForBackedProperties[name];
}

+ (NSString *)typeOfPropertyNamed:(NSString *)name
{
    objc_property_t property = class_getProperty(self, [name UTF8String]);
    if (property == NULL) {
        return nil;
    }
    const char *attrs = property_getAttributes(property);
    if (attrs == NULL) {
        return nil;
    }
    NSString *attrString = @(attrs);
    NSArray *splitOnComma = [attrString componentsSeparatedByString:@","];
    NSString *encodedType = splitOnComma.firstObject;
    // encoded types are either T{primative_type_key} or T@"{object_class_name}"
    // so we ignore things that don't start with T
    if (encodedType.length < 1) {
        return nil;
    }
    // then we ignore the T
    encodedType = [encodedType substringFromIndex:1];

    // for subclasses of NSObject, we strip the opening @" and closing "
    if (encodedType.length >= 3 && [[encodedType substringToIndex:2] isEqualToString:@"@\""]) {
        NSString *objectType = [encodedType substringFromIndex:2];
        return [objectType substringToIndex:objectType.length - 1];
    }

    NSDictionary *primitivesMapping = [self encodedPrimitiveTypeToType];
    return primitivesMapping[encodedType]; // may be nil if unrecognized type
}

+ (NSDictionary *)encodedPrimitiveTypeToType
{
    return @{
            // boolean
            @"B" : @"BOOL",
            @"c" : @"BOOL",

            // integer
            @"s" : @"short",
            @"S" : @"unsigned short",
            @"i" : @"int",
            @"I" : @"unsigned int",
            @"q" : @"long",
            @"Q" : @"unsigned long",

            // floating point
            @"f" : @"float",
            @"d" : @"double",
            @"D" : @"long double",
    };
}

+ (BOOL)typeIsPrimitive:(NSString *)type
{
    return [[[self encodedPrimitiveTypeToType] allValues] containsObject:type];
}

+ (id)legacyValueForProperty:(NSString *)property
{
    return nil;
}

+ (id)defaultValueForProperty:(NSString *)property
{
    return nil;
}

+ (NSDictionary *)genericTypesForBackedProperties
{
    return nil;
}

- (void)prepareWritingFor:(NSString *)property
{
    [self addObserver:self
           forKeyPath:property
              options:0
              context:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    if ([self.class.keychainBackedProperties containsObject:keyPath]) {
        [self writeToKeychainForProperty:keyPath];
    } else if ([self.class.defaultsBackedProperties containsObject:keyPath]) {
        [self writeToDefaultsForProperty:keyPath];
    } else {
        [super observeValueForKeyPath:keyPath
                             ofObject:object
                               change:change
                              context:context];
    }
}

#pragma mark keychain
+ (NSArray *)keychainBackedProperties
{
    return @[];
}

+ (NSString *)keychainNamespace
{
    NSDictionary *info = [NSBundle mainBundle].infoDictionary;
    return info[@"CFBundleDisplayName"];
}

+ (KeychainItemWrapper *)makeKeychainFor:(NSString *)property
{
    NSString *identifier = [self.class.keychainNamespace stringByAppendingString:property];
    return [[KeychainItemWrapper alloc] initWithIdentifier:identifier
                                               accessGroup:nil];
}

+ (id)valueOfKeychainFor:(NSString *)property
{
    KeychainItemWrapper *keychain = [self makeKeychainFor:property];
    return [self valueOfKeychain:keychain];
}

+ (id)valueOfKeychain:(KeychainItemWrapper *)keychain
{
    return [keychain objectForKey:(__bridge id)kSecValueData];
}

+ (void)setValue:(id)value
      toKeychain:(KeychainItemWrapper *)keychain
{
    [keychain setObject:value
                 forKey:(__bridge id)kSecValueData];
}

+ (void)resetKeychainItems
{
    for (NSString *property in self.keychainBackedProperties) {
        [[self makeKeychainFor:property] resetKeychainItem];

        if ([self respondsToSelector:@selector(singleton)] && [self respondsToSelector:@selector(hasBeenCreated)] && [self hasBeenCreated]) {
            id singleton = [self singleton];
            NSString *type = [self typeOfPropertyNamed:property];
            BOOL isPrimitive = [self typeIsPrimitive:type];
            if (isPrimitive) {
                [singleton setValue:@0
                             forKey:property];
            } else {
                [singleton setValue:nil
                             forKey:property];
            }
        }
    }
}

- (void)initializeKeychainProperties
{
    NSArray *keychainBackedProperties = self.class.keychainBackedProperties;
    self.keychains = [NSMutableDictionary dictionaryWithCapacity:keychainBackedProperties.count];
    for (NSString *property in keychainBackedProperties) {
        self.keychains[property] = [self.class makeKeychainFor:property];
        [self prepareWritingFor:property];
        [self initializeFromKeychain:property];
    }
}

- (void)initializeFromKeychain:(NSString *)property
{
    KeychainItemWrapper *wrapper = (self.keychains)[property];
    id value = [self.class valueOfKeychain:wrapper];

    if ([self isEmptyValue:value]) {
        value = [self.class legacyValueForProperty:property];
        if ([self isEmptyValue:value]) {
            value = [self.class defaultValueForProperty:property];
            if ([self isEmptyValue:value]) {
                return;
            }
        }
    }

    NSString *type = [[self class] typeOfPropertyNamed:property];
    Class klass = NSClassFromString(type);
    if ([klass isSubclassOfClass:[NSDate class]]) {
        // keychains don't play nice with NSDates, so we have to parse back from a timestamp
        value = [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
    } else if ([klass isSubclassOfClass:[CLKModel class]]) {
        value = [[klass alloc] initFromString:value];
    } else if ([[self class] typeIsPrimitive:type]) {
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        formatter.numberStyle = NSNumberFormatterDecimalStyle;
        value = [formatter numberFromString:value];
    } else {
        value = [self mutableValueForValue:value
                                   ofClass:klass];
    }

    [self setValue:value
            forKey:property];
}

- (BOOL)isEmptyValue:(id)value
{
    if ([value isKindOfClass:[CLKModel class]]) {
        return NO;
    }
    NSString *valueStr = (NSString *)value;
    return ((valueStr == (id)[NSNull null]) || (valueStr.length == 0));
}

- (void)writeToKeychainForProperty:(NSString *)property
{
    id value = [self valueForKey:property];
    NSString *type = [[self class] typeOfPropertyNamed:property];
    KeychainItemWrapper *wrapper = self.keychains[property];

    BOOL isPrimitive = [self.class typeIsPrimitive:type];
    if (isPrimitive) {
        value = [NSString stringWithFormat:@"%@",
                                           value];
    } else if ([type isEqualToString:@"NSString"]) {
        value = value ? value : @"";
    } else if ([type isEqualToString:@"NSDate"]) {
        if (value) {
            // keychains don't play nice with NSDates, so we write as a timestamp
            NSDate *date = (NSDate *)value;
            value = [NSString stringWithFormat:@"%f",
                                               date.timeIntervalSince1970];
        } else {
            value = @"";
        }
    }

    Class klass = NSClassFromString(type);
    if (klass && [klass isSubclassOfClass:[CLKModel class]]) {
        CLKModel *model = (CLKModel *)value;
        value = [model toString];
    }

    [self.class setValue:value
              toKeychain:wrapper];
}

- (void)cleanupKeychainObservers
{
    for (NSString *property in self.class.keychainBackedProperties) {
        [self removeObserver:self
                  forKeyPath:property];
    }
}

#pragma mark defaults
+ (NSArray *)defaultsBackedProperties
{
    return @[];
}

+ (NSString *)defaultsKeyForProperty:(NSString *)property
{
    return [NSString stringWithFormat:@"%@_%@",
                                      self,
                                      property];
}

- (void)initializeDefaultsProperties
{
    for (NSString *property in self.class.defaultsBackedProperties) {
        [self prepareWritingFor:property];
        [self initializeFromDefaults:property];
    }
}

- (void)initializeFromDefaults:(NSString *)property
{
    NSString *defaultsKey = [self.class defaultsKeyForProperty:property];
    
    // note that objectForKey returns an immutable object even if the value you originally set was mutable.
    id value = [[NSUserDefaults standardUserDefaults] objectForKey:defaultsKey];

    NSString *type = [self.class typeOfPropertyNamed:property];
    Class klass = NSClassFromString(type);

    value = [self mutableValueForValue:value
                               ofClass:klass];
    if (value && klass) {
        if ([klass isSubclassOfClass:[CLKModel class]]) {
            CLKModel *model = (CLKModel *)[klass alloc];
            value = [model initFromJSON:value];
        } else if ([klass isSubclassOfClass:[NSArray class]]) {
            NSArray *array = (NSArray *)value;
            NSString *genericType = [self.class genericTypeOfPropertyNamed:property];
            Class genericKlass = NSClassFromString(genericType);
            if ([genericKlass isSubclassOfClass:[CLKModel class]]) {
                value = [array map:^CLKModel *(NSDictionary *json) {
                    return [(CLKModel *)[genericKlass alloc] initFromJSON:json];
                }];
            }
        }
    }

    if (!value) {
        value = [self.class legacyValueForProperty:property];
        // TODO: delete legacy value from disk
        if (!value) {
            value = [self.class defaultValueForProperty:property];
        }
    }

    if (value) {
        if ([type isEqualToString:@"NSMutableDictionary"]) {
            value = [(NSDictionary *)value mutableCopy];
        } else if ([type isEqualToString:@"NSMutableString"]) {
            value = [(NSString *)value mutableCopy];
        } else if ([type isEqualToString:@"NSMutableArray"]) {
            value = [(NSArray *)value mutableCopy];
        }
        [self setValue:value
                forKey:property];
    }
}

- (id)mutableValueForValue:(id)value
                   ofClass:(Class)klass
{
    if (!klass) {
        return value;
    }

    if ([klass isSubclassOfClass:[NSMutableArray class]]) {
        return [(NSArray *)value mutableCopy];
    }

    if ([klass isSubclassOfClass:[NSMutableSet class]]) {
        return [(NSSet *)value mutableCopy];
    }

    if ([klass isSubclassOfClass:[NSMutableString class]]) {
        return [(NSString *)value mutableCopy];
    }

    if ([klass isSubclassOfClass:[NSMutableDictionary class]]) {
        return [(NSDictionary *)value mutableCopy];
    }

    if ([klass isSubclassOfClass:[NSMutableData class]]) {
        return [(NSData *)value mutableCopy];
    }

    return value;
}

- (void)writeToDefaultsForProperty:(NSString *)property
{
    id value = [self valueForKey:property];
    NSString *type = [self.class typeOfPropertyNamed:property];
    Class klass = NSClassFromString(type);
    if (value && klass) {
        if ([klass isSubclassOfClass:[CLKModel class]]) {
            CLKModel *model = (CLKModel *)value;
            value = [model toJSON];
        } else if ([klass isSubclassOfClass:[NSArray class]]) {
            NSArray *array = (NSArray *)value;
            NSString *genericType = [self.class genericTypeOfPropertyNamed:property];
            Class genericKlass = NSClassFromString(genericType);
            if ([genericKlass isSubclassOfClass:[CLKModel class]]) {
                value = [array map:^NSDictionary *(CLKModel *object) {
                    if ([object isKindOfClass:genericKlass]) {
                        return [object toJSON];
                    }
                    return nil;
                }];
            }
        }
    }


    NSString *defaultsKey = [self.class defaultsKeyForProperty:property];
    if (value) {
        [[NSUserDefaults standardUserDefaults] setObject:value
                                                  forKey:defaultsKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
    }
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)cleanupDefaultsObservers
{
    for (NSString *property in self.class.defaultsBackedProperties) {
        [self removeObserver:self
                  forKeyPath:property];
    }
}

#pragma mark temporary disk clearing house
+ (NSArray *)whitelistedKeys
{
    // subclasses can implement custom
    return @[];
}

+ (void)clearAllDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    NSDictionary *dictionaryOfDefaults = [defaults dictionaryRepresentation];

    NSArray *whitelistedKeys = [self whitelistedKeys];
    for (NSString *key in dictionaryOfDefaults.allKeys) {
        if (![whitelistedKeys containsObject:key]) {
            [defaults removeObjectForKey:key];
        }
    }
    [defaults synchronize];
}

+ (void)resetDefaultsItems
{
    for (NSString *property in self.defaultsBackedProperties) {
        NSString *defaultsKey = [self.class defaultsKeyForProperty:property];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:defaultsKey];
    }
}

+ (void)clearAllKeychains
{
    // implementable by subclass
}

- (NSString *)description
{
    NSString *jsonString = [CLKUtilities jsonFromCollection:[self toJSON] prettyPrinted:NO];
    return [NSString stringWithFormat:@"%@ with JSON %@", [super description], jsonString];
}

@end
