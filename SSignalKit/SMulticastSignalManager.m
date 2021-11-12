#import "SMulticastSignalManager.h"

#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMetaDisposable.h"
#import "SSignal+Multicast.h"
#import "SSignal+SideEffects.h"

#import "SMutexLock.h"

@interface SMulticastSignalManager () {
    SMutexLock *_lock;
    NSMutableDictionary *_multicastSignals;
    NSMutableDictionary *_standaloneSignalDisposables;
    NSMutableDictionary *_pipeListeners;
}

@end

@implementation SMulticastSignalManager

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
        _multicastSignals = [[NSMutableDictionary alloc] init];
        _standaloneSignalDisposables = [[NSMutableDictionary alloc] init];
        _pipeListeners = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)dealloc {
    __block NSArray *disposables = nil;
    [_lock locked:^{
        disposables = [_standaloneSignalDisposables allValues];
    }];

    for (id<SDisposable> disposable in disposables) {
        [disposable dispose];
    }
}

- (SSignal *)multicastedSignalForKey:(NSString *)key producer:(SSignal * (^)(void))producer {
    if (!key) {
        if (producer) {
            return producer();
        } else {
            return nil;
        }
    }

    __block SSignal *signal = nil;
    [_lock locked:^{
        signal = _multicastSignals[key];
        if (!signal) {
            __weak SMulticastSignalManager *weakSelf = self;
            if (producer) {
                signal = producer();
            }
            if (signal) {
                signal = [[signal onDispose:^{
                    __strong SMulticastSignalManager *strongSelf = weakSelf;
                    if (strongSelf) {
                        [strongSelf->_lock locked:^{
                            [strongSelf->_multicastSignals removeObjectForKey:key];
                        }];
                    }
                }] multicast];
                _multicastSignals[key] = signal;
            }
        }
    }];

    return signal;
}

- (void)startStandaloneSignalIfNotRunningForKey:(NSString *)key producer:(SSignal * (^)(void))producer {
    if (!key) {
        return;
    }

    __block BOOL produce = NO;
    [_lock locked:^{
        if (!_standaloneSignalDisposables[key]) {
            _standaloneSignalDisposables[key] = [[SMetaDisposable alloc] init];
            produce = YES;
        }
    }];

    if (produce) {
        __weak SMulticastSignalManager *weakSelf = self;
        id<SDisposable> disposable = [producer() startWithNext:nil
            error:^(__unused id error) {
                __strong SMulticastSignalManager *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf->_lock locked:^{
                        [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                    }];
                }
            }
            completed:^{
                __strong SMulticastSignalManager *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf->_lock locked:^{
                        [strongSelf->_standaloneSignalDisposables removeObjectForKey:key];
                    }];
                }
            }];

        [_lock locked:^{
            [(SMetaDisposable *)_standaloneSignalDisposables[key] setDisposable:disposable];
        }];
    }
}

- (SSignal *)multicastedPipeForKey:(NSString *)key {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        __block NSInteger index;
        [self->_lock locked:^{
            SBag *bag = self->_pipeListeners[key];
            if (!bag) {
                bag = [[SBag alloc] init];
                self->_pipeListeners[key] = bag;
            }
            index = [bag addItem:[^(id next) {
                             [subscriber putNext:next];
                         } copy]];
        }];

        return [[SBlockDisposable alloc] initWithBlock:^{
            [self->_lock locked:^{
                SBag *bag = self->_pipeListeners[key];
                [bag removeItem:index];
                if ([bag isEmpty]) {
                    [self->_pipeListeners removeObjectForKey:key];
                }
            }];
        }];
    }];
}

- (void)putNext:(id)next toMulticastedPipeForKey:(NSString *)key {
    __block NSArray *pipeListeners;
    [_lock locked:^{
        pipeListeners = [(SBag *)_pipeListeners[key] copyItems];
    }];

    for (void (^listener)(id) in pipeListeners) {
        listener(next);
    }
}

@end
