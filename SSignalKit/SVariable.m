#import "SVariable.h"

#import "SMutexLock.h"

#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"
#import "SSignal.h"

@interface SVariable () {
    SMutexLock *_lock;
    id _value;
    BOOL _hasValue;
    SBag *_subscribers;
    SMetaDisposable *_disposable;
}

@end

@implementation SVariable

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
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
        __block id currentValue;
        __block BOOL hasValue;
        __block NSInteger index;
        [self->_lock locked:^{
            currentValue = self->_value;
            hasValue = self->_hasValue;
            index = [self->_subscribers addItem:[^(id value) {
                                            [subscriber putNext:value];
                                        } copy]];
        }];

        if (hasValue) {
            [subscriber putNext:currentValue];
        }

        return [[SBlockDisposable alloc] initWithBlock:^{
            [self->_lock locked:^{
                [self->_subscribers removeItem:index];
            }];
        }];
    }];
}

- (void)set:(SSignal *)signal {
    [_lock locked:^{
        _hasValue = NO;
    }];

    __weak SVariable *weakSelf = self;
    [_disposable setDisposable:[signal startWithNext:^(id next) {
                     __strong SVariable *strongSelf = weakSelf;
                     if (strongSelf) {
                         __block NSArray *subscribers = nil;
                         [strongSelf->_lock locked:^{
                             strongSelf->_value = next;
                             strongSelf->_hasValue = YES;
                             subscribers = [strongSelf->_subscribers copyItems];
                         }];

                         for (void (^subscriber)(id) in subscribers) {
                             subscriber(next);
                         }
                     }
                 }]];
}

@end
