#import "SBlockDisposable.h"

#import <objc/runtime.h>
#import <os/lock.h>
#import <stdatomic.h>

@interface SBlockDisposable () {
    _Atomic(void *) _block;
}

@end

@implementation SBlockDisposable

- (instancetype)initWithBlock:(void (^)(void))block {
    if (self = [super init]) {
        _block = (__bridge_retained void *)[block copy];
    }
    return self;
}

- (void)dealloc {
    void *block = _block;
    if (block) {
        if (atomic_compare_exchange_strong(&_block, &block, NULL)) {
            if (block) {
                __strong id strongBlock = (__bridge_transfer id)block;
                strongBlock = nil;
            }
        }
    }
}

- (void)dispose {
    void *block = _block;
    if (block) {
        if (atomic_compare_exchange_strong(&_block, &block, NULL)) {
            if (block) {
                __strong id strongBlock = (__bridge_transfer id)block;
                ((dispatch_block_t)strongBlock)();
                strongBlock = nil;
            }
        }
    }
}

@end
