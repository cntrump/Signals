#import "SMetaDisposable.h"

#import <os/lock.h>

@interface SMetaDisposable () {
    os_unfair_lock _lock;
    BOOL _disposed;
    id<SDisposable> _disposable;
}

@end

@implementation SMetaDisposable

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
    }

    return self;
}

- (void)setDisposable:(id<SDisposable>)disposable {
    id<SDisposable> previousDisposable = nil;
    BOOL dispose = NO;

    os_unfair_lock_lock(&_lock);
    dispose = _disposed;
    if (!dispose) {
        previousDisposable = _disposable;
        _disposable = disposable;
    }
    os_unfair_lock_unlock(&_lock);

    if (previousDisposable) {
        [previousDisposable dispose];
    }

    if (dispose)
        [disposable dispose];
}

- (void)dispose {
    id<SDisposable> disposable = nil;

    os_unfair_lock_lock(&_lock);
    if (!_disposed) {
        disposable = _disposable;
        _disposed = YES;
    }
    os_unfair_lock_unlock(&_lock);

    if (disposable) {
        [disposable dispose];
    }
}

@end
