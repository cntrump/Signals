
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SMutexLock : NSObject

- (void)locked:(void (NS_NOESCAPE ^)(void))block;

@end

NS_ASSUME_NONNULL_END
