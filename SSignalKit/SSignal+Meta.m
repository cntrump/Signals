#import "SSignal+Meta.h"

#import "SAtomic.h"
#import "SDisposableSet.h"
#import "SMetaDisposable.h"
#import "SSignal+Mapping.h"
#import "SSignal+Pipe.h"

#import "SMutexLock.h"

@interface SSignalQueueState : NSObject <SDisposable> {
    SMutexLock *_lock;
    BOOL _executingSignal;
    BOOL _terminated;

    id<SDisposable> _disposable;
    SMetaDisposable *_currentDisposable;
    SSubscriber *_subscriber;

    NSMutableArray *_queuedSignals;
    BOOL _queueMode;
    BOOL _throttleMode;
}

@end

@implementation SSignalQueueState

- (instancetype)initWithSubscriber:(SSubscriber *)subscriber queueMode:(BOOL)queueMode throttleMode:(BOOL)throttleMode {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
        _subscriber = subscriber;
        _currentDisposable = [[SMetaDisposable alloc] init];
        _queuedSignals = queueMode ? [[NSMutableArray alloc] init] : nil;
        _queueMode = queueMode;
        _throttleMode = throttleMode;
    }
    return self;
}

- (void)beginWithDisposable:(id<SDisposable>)disposable {
    _disposable = disposable;
}

- (void)enqueueSignal:(SSignal *)signal {
    __block BOOL startSignal = NO;
    [_lock locked:^{
        if (_queueMode && _executingSignal) {
            if (_throttleMode) {
                [_queuedSignals removeAllObjects];
            }
            [_queuedSignals addObject:signal];
        } else {
            _executingSignal = YES;
            startSignal = YES;
        }
    }];

    if (startSignal) {
        __weak SSignalQueueState *weakSelf = self;
        id<SDisposable> disposable = [signal
            startWithNext:^(id next) {
                [self->_subscriber putNext:next];
            }
            error:^(id error) {
                [self->_subscriber putError:error];
            }
            completed:^{
                __strong SSignalQueueState *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf headCompleted];
                }
            }];

        [_currentDisposable setDisposable:disposable];
    }
}

- (void)headCompleted {
    __block SSignal *nextSignal = nil;

    __block BOOL terminated = NO;
    [_lock locked:^{
        _executingSignal = NO;

        if (_queueMode) {
            if (_queuedSignals.count != 0) {
                nextSignal = _queuedSignals[0];
                [_queuedSignals removeObjectAtIndex:0];
                _executingSignal = YES;
            } else {
                terminated = _terminated;
            }
        } else {
            terminated = _terminated;
        }
    }];

    if (terminated) {
        [_subscriber putCompletion];
    } else if (nextSignal) {
        __weak SSignalQueueState *weakSelf = self;
        id<SDisposable> disposable = [nextSignal
            startWithNext:^(id next) {
                [self->_subscriber putNext:next];
            }
            error:^(id error) {
                [self->_subscriber putError:error];
            }
            completed:^{
                __strong SSignalQueueState *strongSelf = weakSelf;
                if (strongSelf) {
                    [strongSelf headCompleted];
                }
            }];

        [_currentDisposable setDisposable:disposable];
    }
}

- (void)beginCompletion {
    __block BOOL executingSignal = NO;
    [_lock locked:^{
        executingSignal = _executingSignal;
        _terminated = YES;
    }];

    if (!executingSignal)
        [_subscriber putCompletion];
}

- (void)dispose {
    [_currentDisposable dispose];
    [_disposable dispose];
}

@end

@implementation SSignal (Meta)

- (SSignal *)switchToLatest {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:NO throttleMode:NO];

        [state beginWithDisposable:[self
                                       startWithNext:^(id next) {
                                           [state enqueueSignal:next];
                                       }
                                       error:^(id error) {
                                           [subscriber putError:error];
                                       }
                                       completed:^{
                                           [state beginCompletion];
                                       }]];

        return state;
    }];
}

- (SSignal *)mapToSignal:(SSignal * (^)(id))f {
    return [[self map:f] switchToLatest];
}

- (SSignal *)mapToQueue:(SSignal * (^)(id))f {
    return [[self map:f] queue];
}

- (SSignal *)mapToThrottled:(SSignal * (^)(id))f {
    return [[self map:f] throttled];
}

- (SSignal *)then:(SSignal *)signal {
    return [[SSignal alloc] initWithGenerator:^(SSubscriber *subscriber) {
        SDisposableSet *compositeDisposable = [[SDisposableSet alloc] init];

        SMetaDisposable *currentDisposable = [[SMetaDisposable alloc] init];
        [compositeDisposable add:currentDisposable];

        [currentDisposable setDisposable:[self
                                             startWithNext:^(id next) {
                                                 [subscriber putNext:next];
                                             }
                                             error:^(id error) {
                                                 [subscriber putError:error];
                                             }
                                             completed:^{
                                                 [compositeDisposable add:[signal
                                                                              startWithNext:^(id next) {
                                                                                  [subscriber putNext:next];
                                                                              }
                                                                              error:^(id error) {
                                                                                  [subscriber putError:error];
                                                                              }
                                                                              completed:^{
                                                                                  [subscriber putCompletion];
                                                                              }]];
                                             }]];

        return compositeDisposable;
    }];
}

- (SSignal *)queue {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:YES throttleMode:NO];

        [state beginWithDisposable:[self
                                       startWithNext:^(id next) {
                                           [state enqueueSignal:next];
                                       }
                                       error:^(id error) {
                                           [subscriber putError:error];
                                       }
                                       completed:^{
                                           [state beginCompletion];
                                       }]];

        return state;
    }];
}

- (SSignal *)throttled {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SSignalQueueState *state = [[SSignalQueueState alloc] initWithSubscriber:subscriber queueMode:YES throttleMode:YES];
        [state beginWithDisposable:[self
                                       startWithNext:^(id next) {
                                           [state enqueueSignal:next];
                                       }
                                       error:^(id error) {
                                           [subscriber putError:error];
                                       }
                                       completed:^{
                                           [state beginCompletion];
                                       }]];

        return state;
    }];
}

+ (SSignal *)defer:(SSignal * (^)(void))generator {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        return [generator()
            startWithNext:^(id next) {
                [subscriber putNext:next];
            }
            error:^(id error) {
                [subscriber putError:error];
            }
            completed:^{
                [subscriber putCompletion];
            }];
    }];
}

@end

@interface SSignalQueue () {
    SPipe *_pipe;
    id<SDisposable> _disposable;
}

@end

@implementation SSignalQueue

- (instancetype)init {
    if (self = [super init]) {
        _pipe = [[SPipe alloc] init];
        _disposable = [[_pipe.signalProducer() queue] startWithNext:nil];
    }
    return self;
}

- (void)dealloc {
    [_disposable dispose];
}

- (SSignal *)enqueue:(SSignal *)signal {
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        SPipe *disposePipe = [[SPipe alloc] init];

        SSignal *proxy = [[[[signal onNext:^(id next) {
            [subscriber putNext:next];
        }] onError:^(id error) {
            [subscriber putError:error];
        }] onCompletion:^{
            [subscriber putCompletion];
        }] catch:^SSignal *(__unused id error) {
            return [SSignal complete];
        }];

        self->_pipe.sink([proxy takeUntilReplacement:disposePipe.signalProducer()]);

        return [[SBlockDisposable alloc] initWithBlock:^{
            disposePipe.sink([SSignal complete]);
        }];
    }];
}

@end
