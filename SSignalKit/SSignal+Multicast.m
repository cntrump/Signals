#import "SSignal+Multicast.h"

#import "SBag.h"
#import "SBlockDisposable.h"
#import "SMutexLock.h"

typedef enum {
    SSignalMulticastStateReady,
    SSignalMulticastStateStarted,
    SSignalMulticastStateCompleted
} SSignalMulticastState;

@interface SSignalMulticastSubscribers : NSObject {
    SMutexLock *_lock;
    SBag *_subscribers;
    SSignalMulticastState _state;
    id<SDisposable> _disposable;
}

@end

@implementation SSignalMulticastSubscribers

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
        _subscribers = [[SBag alloc] init];
    }
    return self;
}

- (void)setDisposable:(id<SDisposable>)disposable {
    [_disposable dispose];
    _disposable = disposable;
}

- (id<SDisposable>)addSubscriber:(SSubscriber *)subscriber start:(BOOL *)start {
    __block NSInteger index;
    [_lock locked:^{
        index = [_subscribers addItem:subscriber];
        switch (_state) {
            case SSignalMulticastStateReady:
                *start = YES;
                _state = SSignalMulticastStateStarted;
                break;
            default:
                break;
        }
    }];

    return [[SBlockDisposable alloc] initWithBlock:^{
        [self remove:index];
    }];
}

- (void)remove:(NSInteger)index {
    __block id<SDisposable> currentDisposable = nil;

    [_lock locked:^{
        [_subscribers removeItem:index];
        switch (_state) {
            case SSignalMulticastStateStarted:
                if ([_subscribers isEmpty]) {
                    currentDisposable = _disposable;
                    _disposable = nil;
                }
                break;
            default:
                break;
        }
    }];

    [currentDisposable dispose];
}

- (void)notifyNext:(id)next {
    __block NSArray *currentSubscribers = nil;
    [_lock locked:^{
        currentSubscribers = [_subscribers copyItems];
    }];

    for (SSubscriber *subscriber in currentSubscribers) {
        [subscriber putNext:next];
    }
}

- (void)notifyError:(id)error {
    __block NSArray *currentSubscribers = nil;
    [_lock locked:^{
        currentSubscribers = [_subscribers copyItems];
        _state = SSignalMulticastStateCompleted;
    }];

    for (SSubscriber *subscriber in currentSubscribers) {
        [subscriber putError:error];
    }
}

- (void)notifyCompleted {
    __block NSArray *currentSubscribers = nil;
    [_lock locked:^{
        currentSubscribers = [_subscribers copyItems];
        _state = SSignalMulticastStateCompleted;
    }];

    for (SSubscriber *subscriber in currentSubscribers) {
        [subscriber putCompletion];
    }
}

@end

@implementation SSignal (Multicast)

- (SSignal *)multicast {
    SSignalMulticastSubscribers *subscribers = [[SSignalMulticastSubscribers alloc] init];
    return [[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
        BOOL start = NO;
        id<SDisposable> currentDisposable = [subscribers addSubscriber:subscriber start:&start];
        if (start) {
            id<SDisposable> disposable = [self
                startWithNext:^(id next) {
                    [subscribers notifyNext:next];
                }
                error:^(id error) {
                    [subscribers notifyError:error];
                }
                completed:^{
                    [subscribers notifyCompleted];
                }];

            [subscribers setDisposable:[[SBlockDisposable alloc] initWithBlock:^{
                             [disposable dispose];
                         }]];
        }

        return currentDisposable;
    }];
}

@end
