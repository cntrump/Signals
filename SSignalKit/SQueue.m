#import "SQueue.h"

static const void *SQueueSpecificKey = &SQueueSpecificKey;

@interface SQueue () {
    dispatch_queue_t _queue;
    void *_queueSpecific;
    BOOL _specialIsMainQueue;
}

@end

@implementation SQueue

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue {
    return [[SQueue alloc] initWithNativeQueue:nativeQueue queueSpecific:NULL];
}

- (instancetype)init {
    dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
    dispatch_queue_set_specific(queue, SQueueSpecificKey, (__bridge void *)self, NULL);
    return [self initWithNativeQueue:queue queueSpecific:(__bridge void *)self];
}

- (instancetype)initWithNativeQueue:(dispatch_queue_t)queue queueSpecific:(void *)queueSpecific {
    if (self = [super init]) {
        _queue = queue;
        _queueSpecific = queueSpecific;
    }
    return self;
}

- (dispatch_queue_t)_dispatch_queue {
    return _queue;
}

- (void)dispatch:(dispatch_block_t)block {
    if (_queueSpecific && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific) {
        block();
    } else if (_specialIsMainQueue && [NSThread isMainThread]) {
        block();
    } else {
        dispatch_async(_queue, block);
    }
}

- (void)dispatchSync:(dispatch_block_t)block {
    if (_queueSpecific && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific) {
        block();
    } else if (_specialIsMainQueue && [NSThread isMainThread]) {
        block();
    } else {
        dispatch_sync(_queue, block);
    }
}

- (void)dispatch:(dispatch_block_t)block synchronous:(BOOL)synchronous {
    if (_queueSpecific && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific) {
        block();
    } else if (_specialIsMainQueue && [NSThread isMainThread]) {
        block();
    } else {
        if (synchronous) {
            dispatch_sync(_queue, block);
        } else {
            dispatch_async(_queue, block);
        }
    }
}

- (BOOL)isCurrentQueue {
    if (_queueSpecific && dispatch_get_specific(SQueueSpecificKey) == _queueSpecific) {
        return YES;
    } else if (_specialIsMainQueue && [NSThread isMainThread]) {
        return YES;
    }
    return NO;
}

@end

@implementation SQueue (Global)

+ (SQueue *)main {
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_main_queue() queueSpecific:NULL];
        queue->_specialIsMainQueue = YES;
    });

    return queue;
}

+ (SQueue *)concurrentDefault {
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0) queueSpecific:NULL];
    });

    return queue;
}

+ (SQueue *)concurrentBackground {
    static SQueue *queue = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        queue = [[SQueue alloc] initWithNativeQueue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0) queueSpecific:NULL];
    });

    return queue;
}

@end
