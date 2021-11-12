#import "SMetaDisposable.h"

#import "SMutexLock.h"

@interface SMetaDisposable () {
    SMutexLock *_lock;
    BOOL _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (instancetype)init {
    if (self = [super init]) {
        _lock = [[SMutexLock alloc] init];
    }

    return self;
}

- (void)setDisposable:(id<SDisposable>)disposable {
    __block id<SDisposable> previousDisposable = nil;
    __block BOOL dispose = NO;

    [_lock locked:^{
        dispose = _disposed;
        if (!dispose) {
            previousDisposable = _disposable;
            _disposable = disposable;
        }
    }];

    if (previousDisposable) {
        [previousDisposable dispose];
    }

    if (dispose)
        [disposable dispose];
}

- (void)dispose {
    __block id<SDisposable> disposable = nil;

    [_lock locked:^{
        if (!_disposed) {
            disposable = _disposable;
            _disposed = YES;
        }
    }];

    if (disposable) {
        [disposable dispose];
    }
}

@end
