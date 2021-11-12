#import "SAtomic.h"
#import "SMutexLock.h"

@interface SAtomic () {
    SMutexLock *_lock;
    id _value;
}

@end

@implementation SAtomic

- (instancetype)initWithValue:(id)value {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
        _value = value;
    }
    return self;
}

- (id)swap:(id)newValue {
    __block id previousValue = nil;
    [_lock locked:^{
        previousValue = _value;
        _value = newValue;
    }];
    return previousValue;
}

- (id)value {
    __block id previousValue = nil;
    [_lock locked:^{
        previousValue = _value;
    }];

    return previousValue;
}

- (id)modify:(id (^)(id))f {
    __block id newValue = nil;
    [_lock locked:^{
        newValue = f(_value);
        _value = newValue;
    }];
    return newValue;
}

- (id)with:(id (^)(id))f {
    __block id result = nil;
    [_lock locked:^{
        result = f(_value);
    }];
    return result;
}

@end
