#import <SSignalKit/SSubscriber.h>

@interface SSignal : NSObject
{
@public
    id<SDisposable> (^_generator)(SSubscriber *);
}

- (instancetype)initWithGenerator:(id<SDisposable> (^)(SSubscriber *))generator;

- (id<SDisposable>)startWithNext:(void (^)(id next))next error:(void (^)(id error))error completed:(void (^)(void))completed;
- (id<SDisposable>)startWithNext:(void (^)(id next))next;
- (id<SDisposable>)startWithNext:(void (^)(id next))next completed:(void (^)(void))completed;

- (SSignal *)trace:(NSString *)name;

@end

