# CLKModel

`CLKModel` provides an excellent superclass for your Cocoa app's data types.

`CLKModel` handles parsing to and from `JSON`, including nested parsing of subsequent `CLKModel` subclasses and generic types in arrays.  This is achieved through dynamic introspection on the property's type at runtime, paired with a simple `blueprint` that provides the mapping between keys and properties.

CLKModel also provides the ability to store a particular property to disk, either using `NSUserDefaults` or Apple's `Security` framework.  This feature will store any `CLKModels` as `NSDictionary`, inflating and deflating them automatically.

## Example

Here is a simple instance of a `CLKModel` subclass


```objc
@interface Person : CLKModel

@property (atomic, copy) NSString *firstName;
@property (atomic, strong) NSDate *dateOfBirth;
@property (atomic, assign) CGFloat heightInMeters;

@end


@implementation Person

+ (NSDictionary *)blueprint
{
    return @{
            @"first_name" : @"firstName",
            @"dob" : @"dateOfBirth",
            @"height" : @"heightInMeters"
    };
}

@end
```

This can now be inflated and deflated like:

```objc
NSDictionary *personInfo = @{
    @"first_name" : @"John",
    @"dob" : @(635908156000),
    @"height" : @(1.83)
};
Person *person = [[Person alloc] initFromJSON:personInfo];
NSDictionary *personInfoOut = [person toJSON];
```

`personInfo` is now equal to `personInfoOut`.

## Parsed Types

CLKModel handles:

* `NSString`
* `NSArray`
* `NSDictionary`
* All primitive types (`int`, `float`, `double`, `NSInteger` etc.)
* `NSDate` provided as an `NSNumber` or `NSString` in millis since epoch
* `CLKModel` subclasses, which are inflated and deflated recursively

If you have a JSON array of primitives or strings, that'll parse with no extra code.  If the array contains JSON that you'd like to parse into subsequent `CLKModels`, simply define a generic in your blueprint as follows:


```objc
+ (NSDictionary *)blueprint
{
    return @{
            @"comments": @{
                    @"is_array": @YES,
                    @"property": @"comments",
                    @"class": @"Comment"
                    }
}
```

This class will now recursively inflate and deflate arrays of comments as instances of the `Comment` model, which itself is a `CLKModel` subclass with its own blueprint.  Boom!
