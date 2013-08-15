//
//  APPromiseLeakTests.m
//  APPromise
//
//  Created by Andrew Pleshkov on 8/15/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "APPromiseLeakTests.h"
#import "APPromise+Mutator.h"
#import "APPromiseTestsDef.h"

@implementation APPromiseLeakTests

- (void)testLeaks {
   int count = 0;
   for (int i = 0; i < 10; i++) {
      if ([self _testLeak1]) {
         count++;
      }
   }
   STAssertTrue(count > 0, nil);
   
   count = 0;
   for (int i = 0; i < 10; i++) {
      if ([self _testLeak2]) {
         count++;
      }
   }
   STAssertTrue(count > 0, nil);
}

- (BOOL)_testLeak1 {
   __block APPromise *__weak weakPromise;
   
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
   dispatch_async(queue, ^{
      APPromise *promise = [APPromise promise];
      weakPromise = promise;
      
      NSMutableArray *tmp = [NSMutableArray array];
      [promise thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                        ifFulfilled:^id(id value) {
                           [tmp addObject:promise];
                           return value;
                        } rejected:nil];
      
      [promise fulfillWithValue:@1];
      
      while ( ! promise.isFulfilled) {}
      while ( ! tmp.count) {}
   });
   dispatch_sync(queue, ^{});
   APPromiseDispatchRelease(queue);
   
   return ( ! weakPromise);
}

- (BOOL)_testLeak2 {
   __block APPromise *__weak weakPromise;
   
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
   dispatch_async(queue, ^{
      APPromise *promise = [APPromise promise];
      weakPromise = promise;
      
      NSMutableArray *tmp = [NSMutableArray array];
      [promise thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                        ifFulfilled:nil
                           rejected:^id(id reason) {
                              [tmp addObject:promise];
                              return reason;
                           }];
      
      [promise rejectWithReason:@1];
      
      while ( ! promise.isRejected) {}
      while ( ! tmp.count) {}
   });
   dispatch_sync(queue, ^{});
   APPromiseDispatchRelease(queue);
   
   return ( ! weakPromise);
}

@end
