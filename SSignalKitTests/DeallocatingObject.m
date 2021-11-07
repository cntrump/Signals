#import "DeallocatingObject.h"

@interface DeallocatingObject () {
    BOOL *_deallocated;
}

@end

@implementation DeallocatingObject

- (instancetype)initWithDeallocated:(BOOL *)deallocated {
    if (self = [super init]) {
        _deallocated = deallocated;
    }
    return self;
}

- (void)dealloc {
    *_deallocated = YES;
}

@end
