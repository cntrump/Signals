#import "SVariable.h"

#import <os/lock.h>

#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"
#import "SSignal.h"

@interface SVariable () {
    os_unfair_lock _lock;
    id _value;
    BOOL _hasValue;
    SBag *_subscribers;
    SMetaDisposable *_disposable;
}

@end

@implementation SVariable

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
        _subscribers = [[SBag alloc] init];
        _disposable = [[SMetaDisposable alloc] init];
    }
    return self;
}

- (void)dealloc {
    [_disposable dispose];
}

- (SSignal *)signal {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        os_unfair_lock_lock(&self->_lock);
        id currentValue = self->_value;
        BOOL hasValue = self->_hasValue;
        NSInteger index = [self->_subscribers addItem:[^(id value) {
                                                  [subscriber putNext:value];
                                              } copy]];
        os_unfair_lock_unlock(&self->_lock);

        if (hasValue) {
            [subscriber putNext:currentValue];
        }

        return [[SBlockDisposable alloc] initWithBlock:^{
            os_unfair_lock_lock(&self->_lock);
            [self->_subscribers removeItem:index];
            os_unfair_lock_unlock(&self->_lock);
        }];
    }];
}

- (void)set:(SSignal *)signal {
    os_unfair_lock_lock(&_lock);
    _hasValue = NO;
    os_unfair_lock_unlock(&_lock);

    __weak SVariable *weakSelf = self;
    [_disposable setDisposable:[signal startWithNext:^(id next) {
                     __strong SVariable *strongSelf = weakSelf;
                     if (strongSelf) {
                         NSArray *subscribers = nil;
                         os_unfair_lock_lock(&strongSelf->_lock);
                         strongSelf->_value = next;
                         strongSelf->_hasValue = YES;
                         subscribers = [strongSelf->_subscribers copyItems];
                         os_unfair_lock_unlock(&strongSelf->_lock);

                         for (void (^subscriber)(id) in subscribers) {
                             subscriber(next);
                         }
                     }
                 }]];
}

@end
