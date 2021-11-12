#import "SDisposableSet.h"

#import "SSignal.h"

#import "SMutexLock.h"

@interface SDisposableSet () {
    SMutexLock *_lock;
    BOOL _disposed;
    id<SDisposable> _singleDisposable;
    NSArray *_multipleDisposables;
}

@end

@implementation SDisposableSet

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
    }

    return self;
}

- (void)add:(id<SDisposable>)disposable {
    if (!disposable) {
        return;
    }

    __block BOOL dispose = NO;

    [_lock locked:^{
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
    }];

    if (dispose)
        [disposable dispose];
}

- (void)remove:(id<SDisposable>)disposable {
    [_lock locked:^{
        if (_multipleDisposables) {
            NSMutableArray *multipleDisposables = [[NSMutableArray alloc] initWithArray:_multipleDisposables];
            [multipleDisposables removeObject:disposable];
            _multipleDisposables = multipleDisposables;
        } else if (_singleDisposable == disposable) {
            _singleDisposable = nil;
        }
    }];
}

- (void)dispose {
    __block id<SDisposable> singleDisposable = nil;
    __block NSArray *multipleDisposables = nil;

    [_lock locked:^{
        if (!_disposed) {
            _disposed = YES;
            singleDisposable = _singleDisposable;
            multipleDisposables = _multipleDisposables;
            _singleDisposable = nil;
            _multipleDisposables = nil;
        }
    }];

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
