#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SQueue : NSObject

+ (SQueue *)wrapConcurrentNativeQueue:(dispatch_queue_t)nativeQueue;

- (void)dispatch:(dispatch_block_t)block;
- (void)dispatchSync:(dispatch_block_t)block;
- (void)dispatch:(dispatch_block_t)block synchronous:(BOOL)synchronous;

- (dispatch_queue_t)_dispatch_queue;

- (BOOL)isCurrentQueue;

@end

@interface SQueue (Global)

@property(nonatomic, class, readonly) SQueue *main;
@property(nonatomic, class, readonly) SQueue *concurrentDefault;
@property(nonatomic, class, readonly) SQueue *concurrentBackground;

@end

NS_ASSUME_NONNULL_END
