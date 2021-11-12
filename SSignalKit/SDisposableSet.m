#import "SDisposableSet.h"

#import "SSignal.h"

#import <os/lock.h>

@interface SDisposableSet () {
    os_unfair_lock _lock;
    BOOL _disposed;
    id<SDisposable> _singleDisposable;
    NSArray *_multipleDisposables;
}

@end

@implementation SDisposableSet

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
    }

    return self;
}

- (void)add:(id<SDisposable>)disposable {
    if (!disposable) {
        return;
    }

    BOOL dispose = NO;

    os_unfair_lock_lock(&_lock);
    dispose = _disposed;
    if (!dispose) {
        if (_multipleDisposables) {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
            [multipleDisposables addObject:disposable];
            _multipleDisposables = multipleDisposables;
        } else if (_singleDisposable) {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithObjects:_singleDisposable, disposable, nil];
            _multipleDisposables = multipleDisposables;
            _singleDisposable = nil;
        } else {
            _singleDisposable = disposable;
        }
    }
    os_unfair_lock_unlock(&_lock);

    if (dispose)
        [disposable dispose];
}

- (void)remove:(id<SDisposable>)disposable {
    os_unfair_lock_lock(&_lock);
    if (_multipleDisposables) {
        NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
        [multipleDisposables removeObject:disposable];
        _multipleDisposables = multipleDisposables;
    } else if (_singleDisposable == disposable) {
        _singleDisposable = nil;
    }
    os_unfair_lock_unlock(&_lock);
}

- (void)dispose {
    id<SDisposable> singleDisposable = nil;
    NSArray *multipleDisposables = nil;

    os_unfair_lock_lock(&_lock);
    if (!_disposed) {
        _disposed = YES;
        singleDisposable = _singleDisposable;
        multipleDisposables = _multipleDisposables;
        _singleDisposable = nil;
        _multipleDisposables = nil;
    }
    os_unfair_lock_unlock(&_lock);

    if (singleDisposable) {
        [singleDisposable dispose];
    }
    if (multipleDisposables) {
        for (id<SDisposable> disposable in multipleDisposables) {
            [disposable dispose];
        }
    }
}

@end
