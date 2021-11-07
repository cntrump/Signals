#import <Foundation/Foundation.h>

#import <SSignalKit/SThreadPoolQueue.h>
#import <SSignalKit/SThreadPoolTask.h>

NS_ASSUME_NONNULL_BEGIN

@interface SThreadPool : NSObject

- (instancetype)initWithThreadCount:(NSUInteger)threadCount threadPriority:(double)threadPriority;

- (void)addTask:(SThreadPoolTask *)task;

- (SThreadPoolQueue *)nextQueue;
- (void)_workOnQueue:(SThreadPoolQueue *)queue block:(void (^)(void))block;

@end

NS_ASSUME_NONNULL_END
