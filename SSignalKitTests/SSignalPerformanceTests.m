
#import <Foundation/Foundation.h>

#import <XCTest/XCTest.h>

#import <SSignalKit/SSignalKit.h>

@interface SSignalPerformanceTests : XCTestCase

@end

@implementation SSignalPerformanceTests

- (void)setUp {
    [super setUp];
}

- (void)tearDown {
    [super tearDown];
}

- (void)testMap {
    [self measureBlock:^{
        SSignal *signal = [[[SSignal alloc] initWithGenerator:^id<SDisposable>(SSubscriber *subscriber) {
            [subscriber putNext:@1];
            [subscriber putCompletion];
            return nil;
        }] map:^id(id value) {
            return value;
        }];

        for (int i = 0; i < 100000; i++) {
            [signal startWithNext:^(__unused id next){

            }];
        }
    }];
}

@end
