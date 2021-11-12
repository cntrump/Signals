
#import "SMutexLock.h"
#import <os/lock.h>

@interface SMutexLock () {
    os_unfair_lock _lock;
}

@end

@implementation SMutexLock

- (instancetype)init {
    if (self = [super init]) {
        _lock = OS_UNFAIR_LOCK_INIT;
    }

    return self;
}

- (void)locked:(void (NS_NOESCAPE ^)(void))block {
    if (!block) {
        return;
    }

    id retained_self = self;  // avoid self dealloc while waiting lock
    os_unfair_lock_lock(&_lock);
    block();
    os_unfair_lock_unlock(&_lock);
    retained_self = nil;
}

@end
