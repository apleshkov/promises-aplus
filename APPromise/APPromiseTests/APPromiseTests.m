//
//  APPromiseTests.m
//  APPromise
//
//  Created by Andrew Pleshkov on 5/31/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "APPromiseTests.h"
#import "APPromise+Mutator.h"
#import "APPromiseTestsDef.h"

@implementation APPromiseTests

- (void)assertInitialPromiseState:(APPromise *)promise {
   STAssertTrue(promise.state == APPromiseStatePending, nil);
   STAssertTrue(promise.value == nil, nil);
   STAssertTrue(promise.reason == nil, nil);
}

- (void)assertIsPromise:(APPromise *)promise fulfilledWithValue:(id)value {
   STAssertTrue(promise.state == APPromiseStateFulfilled, nil);
   STAssertTrue(promise.value == value, nil);
   STAssertTrue(promise.reason == nil, nil);
}

- (void)assertIsPromise:(APPromise *)promise rejectedWithReason:(id)reason {
   STAssertTrue(promise.state == APPromiseStateRejected, nil);
   STAssertTrue(promise.value == nil, nil);
   STAssertTrue(promise.reason == reason, nil);
}

- (APPromise *)createPromise {
   APPromise *promise = [APPromise promise];
   [self assertInitialPromiseState:promise];
   return promise;
}

- (void)testFulfillment {
   APPromise *promise = [self createPromise];
   
   NSNumber *value = @1;
   [promise fulfillWithValue:value]; // dispatch_async(promiseQueue, ...)
   
   [self assertIsPromise:promise fulfilledWithValue:value]; // dispatch_sync(promiseQueue, ...)
}

- (void)testRejection {
   APPromise *promise = [self createPromise];
   
   NSNumber *reason = @1;
   [promise rejectWithReason:reason];
   
   [self assertIsPromise:promise rejectedWithReason:reason];
}

- (void)testStatePersistance1 {
   APPromise *promise = [self createPromise];
   
   NSNumber *value = @1;
   [promise fulfillWithValue:value];
   [promise rejectWithReason:@2];
   
   [self assertIsPromise:promise fulfilledWithValue:value];
}

- (void)testStatePersistance2 {
   APPromise *promise = [self createPromise];
   
   NSNumber *reason = @1;
   [promise rejectWithReason:reason];
   [promise fulfillWithValue:@2];
   
   [self assertIsPromise:promise rejectedWithReason:reason];
}

- (void)testThreadSafety1 {
   APPromise *promise = [self createPromise];
   
   NSNumber *value = @1, *reason = @2;
   
   dispatch_group_t group = dispatch_group_create();
   
   dispatch_group_enter(group);
   dispatch_async(_DEFAULT_DISPATCH_QUEUE, ^{
      [promise fulfillWithValue:value];
      dispatch_group_leave(group);
   });
   
   dispatch_group_enter(group);
   dispatch_async(_DEFAULT_DISPATCH_QUEUE, ^{
      [promise rejectWithReason:reason];
      dispatch_group_leave(group);
   });
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   if (promise.state == APPromiseStateFulfilled) {
      [self assertIsPromise:promise fulfilledWithValue:value];
      [self testThreadSafety1]; // ensure it can be rejected
   } else if (promise.state == APPromiseStateRejected) {
      [self assertIsPromise:promise rejectedWithReason:reason];
   } else {
      STFail(@"Should be fulfilled or rejected");
   }
}

- (void)_testThreadSafetyWithFulfillment:(BOOL)fulfillment {
   APPromise *promise = [self createPromise];
   
   __block NSNumber *finalResult = nil;
   
   dispatch_group_t group = dispatch_group_create();
   
   long queuePriorities[] = {
      DISPATCH_QUEUE_PRIORITY_LOW,
      DISPATCH_QUEUE_PRIORITY_DEFAULT,
      DISPATCH_QUEUE_PRIORITY_HIGH
   };
   for (NSUInteger i = 0; i < 20; i++) {
      dispatch_group_enter(group);
      
      NSNumber *qResult = @(i);
      
      long priority = queuePriorities[arc4random_uniform(3)];
      dispatch_queue_t queue = dispatch_get_global_queue(priority, 0);
      
      dispatch_block_t block;
      
      if (fulfillment) {
         block = ^{
            [promise fulfillWithValue:qResult];
            [promise thenUseDispatchQueue:queue
                              ifFulfilled:^id(id value) {
                                 if ( ! finalResult) {
                                    finalResult = value;
                                 }
                                 dispatch_group_leave(group);
                                 return value;
                              } rejected:nil];
         };
      } else {
         block = ^{
            [promise rejectWithReason:qResult];
            [promise thenUseDispatchQueue:queue
                              ifFulfilled:nil
                                 rejected:^id(id reason) {
                                    if ( ! finalResult) {
                                       finalResult = reason;
                                    }
                                    dispatch_group_leave(group);
                                    return reason;
                                 }];
         };
      }
      
      dispatch_async(queue, block);
   }
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   if (fulfillment) {
      [self assertIsPromise:promise fulfilledWithValue:finalResult];
   } else {
      [self assertIsPromise:promise rejectedWithReason:finalResult];
   }
   
   // The min value is experimental and doesn't cause an infinite recursion
   if ([finalResult integerValue] < 4) {
      [self testThreadSafety2];
   } else {
      // Multithreading!
   }
}

- (void)testThreadSafety2 {
   [self _testThreadSafetyWithFulfillment:YES];
}

- (void)testThreadSafety3 {
   [self _testThreadSafetyWithFulfillment:YES];
}

- (void)testThenAlreadyFulfilled {
   APPromise *promise1 = [self createPromise];
   
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
   
   NSNumber *value = @1;
   
   [promise1 fulfillWithValue:value];
   
   [self assertIsPromise:promise1 fulfilledWithValue:value];
   
   dispatch_semaphore_t sema = dispatch_semaphore_create(0);
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:queue
                                            ifFulfilled:^id(id value) {
                                               dispatch_semaphore_signal(sema);
                                               return value;
                                            } rejected:nil];
   
   dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
   dispatch_sync(queue, ^{});
   
   APPromiseDispatchRelease(sema);
   APPromiseDispatchRelease(queue);
   
   [self assertIsPromise:promise2 fulfilledWithValue:value];
}

- (void)testThenAlreadyRejected {
   APPromise *promise1 = [self createPromise];
   
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
   
   NSNumber *reason = @1;
   
   [promise1 rejectWithReason:reason];
   
   [self assertIsPromise:promise1 rejectedWithReason:reason];
   
   dispatch_semaphore_t sema = dispatch_semaphore_create(0);
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:queue
                                            ifFulfilled:nil
                                               rejected:^id(id reason) {
                                                  dispatch_semaphore_signal(sema);
                                                  return reason;
                                               }];
   
   dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
   dispatch_sync(queue, ^{});
   
   APPromiseDispatchRelease(sema);
   APPromiseDispatchRelease(queue);
   
   [self assertIsPromise:promise2 rejectedWithReason:reason];
}

- (void)testThenFulfill1 {
   APPromise *promise1 = [self createPromise];
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:nil];
   
   NSNumber *value = @1;
   [promise1 fulfillWithValue:value];
   
   dispatch_semaphore_t sema = dispatch_semaphore_create(0);
   dispatch_queue_t queue = dispatch_queue_create(NULL, NULL);
   
   [promise2 thenUseDispatchQueue:queue
                      ifFulfilled:^id(id value) {
                         dispatch_semaphore_signal(sema);
                         return nil;
                      } rejected:nil];
   
   dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
   dispatch_sync(queue, ^{});
   
   APPromiseDispatchRelease(sema);
   APPromiseDispatchRelease(queue);
   
   [self assertIsPromise:promise1 fulfilledWithValue:value];
   [self assertIsPromise:promise2 fulfilledWithValue:value];
}

- (void)testThenFulfill2 {
   APPromise *promise1 = [self createPromise];
   
   NSNumber *value = @1, *newValue = @2;
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:^id(id value) {
                                               return newValue;
                                            } rejected:nil];
   
   [promise1 fulfillWithValue:value];
   
   dispatch_group_t group = dispatch_group_create();
   dispatch_group_enter(group);
   
   [promise2 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                      ifFulfilled:^id(id value) {
                         dispatch_group_leave(group);
                         return nil;
                      } rejected:nil];
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 fulfilledWithValue:value];
   [self assertIsPromise:promise2 fulfilledWithValue:newValue];
}

- (void)testThenFulfill3 {
   APPromise *promise1 = [self createPromise];
   
   NSNumber *value = @1, *newValue = @2;
   
   dispatch_group_t group = dispatch_group_create();
   dispatch_group_enter(group);
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:^id(id value) {
                                               APPromise *returnedPromise = [self createPromise];
                                               
                                               dispatch_async(_LOW_DISPATCH_QUEUE, ^{
                                                  [returnedPromise fulfillWithValue:newValue];
                                               });
                                               
                                               return returnedPromise;
                                            } rejected:nil];
   
   [promise2 thenUseDispatchQueue:_LOW_DISPATCH_QUEUE
                      ifFulfilled:^id(id value) {
                         dispatch_group_leave(group);
                         return nil;
                      } rejected:nil];
   
   [promise1 fulfillWithValue:value];
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 fulfilledWithValue:value];
   [self assertIsPromise:promise2 fulfilledWithValue:newValue];
}

- (void)testThenReject1 {
   APPromise *promise1 = [self createPromise];
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:nil];
   
   NSNumber *reason = @1;
   [promise1 rejectWithReason:reason];
   
   dispatch_group_t group = dispatch_group_create();
   dispatch_group_enter(group);
   
   [promise2 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                      ifFulfilled:nil
                         rejected:^id(id reason) {
                            dispatch_group_leave(group);
                            return nil;
                         }];
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 rejectedWithReason:reason];
   [self assertIsPromise:promise2 rejectedWithReason:reason];
}

- (void)testThenReject2 {
   APPromise *promise1 = [self createPromise];
   
   NSNumber *reason = @1, *newReason = @2;
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:^id(id reason) {
                                                  return newReason;
                                               }];
   
   [promise1 rejectWithReason:reason];
   
   dispatch_group_t group = dispatch_group_create();
   dispatch_group_enter(group);
   
   [promise2 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                      ifFulfilled:nil
                         rejected:^id(id reason) {
                            dispatch_group_leave(group);
                            return nil;
                         }];
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 rejectedWithReason:reason];
   [self assertIsPromise:promise2 rejectedWithReason:newReason];
}

- (void)testThenReject3 {
   APPromise *promise1 = [self createPromise];
   
   NSNumber *reason = @1, *newReason = @2;
   
   dispatch_group_t group = dispatch_group_create();
   dispatch_group_enter(group);
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:^id(id reason) {
                                                  APPromise *returnedPromise = [self createPromise];
                                                  returnedPromise.name = @"RP";
                                                  
                                                  dispatch_async(_LOW_DISPATCH_QUEUE, ^{
                                                     [returnedPromise rejectWithReason:newReason];
                                                  });
                                                  
                                                  return returnedPromise;
                                               }];
   promise2.name = @"P2";
   
   [promise2 thenUseDispatchQueue:_LOW_DISPATCH_QUEUE
                      ifFulfilled:nil
                         rejected:^id(id reason) {
                            dispatch_group_leave(group);
                            return nil;
                         }];
   
   [promise1 rejectWithReason:reason];
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 rejectedWithReason:reason];
   [self assertIsPromise:promise2 rejectedWithReason:newReason];
}

- (void)testThenRejectThenRejectThenFulfill {
   dispatch_group_t group = dispatch_group_create();
   
   NSNumber *value = @YES, *reason1 = @1, *reason2 = @2;
   
   APPromise *promise1 = [self createPromise];
   
   APPromise *promise2 = [promise1 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:^id(id reason) {
                                                  APPromise *returnedPromise = [self createPromise];
                                                  
                                                  dispatch_async(_LOW_DISPATCH_QUEUE, ^{
                                                     [returnedPromise rejectWithReason:reason2]; // reject 2
                                                  });
                                                  
                                                  return returnedPromise;
                                               }];
   
   APPromise *promise3 = [promise2 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                                            ifFulfilled:nil
                                               rejected:^id(id reason) {
                                                  APPromise *returnedPromise = [self createPromise];
                                                  
                                                  dispatch_async(_LOW_DISPATCH_QUEUE, ^{
                                                     [returnedPromise fulfillWithValue:value]; // fulfill!
                                                  });
                                                  
                                                  return returnedPromise;
                                               }];
   
   [promise3 thenUseDispatchQueue:_DEFAULT_DISPATCH_QUEUE
                      ifFulfilled:^id(id v) {
                         dispatch_group_leave(group);
                         return v;
                      } rejected:nil];
   
   dispatch_group_enter(group);
   [promise1 rejectWithReason:reason1]; // reject 1
   
   dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
   APPromiseDispatchRelease(group);
   
   [self assertIsPromise:promise1 rejectedWithReason:reason1];
   [self assertIsPromise:promise2 rejectedWithReason:reason2];
   [self assertIsPromise:promise3 fulfilledWithValue:value];
}

- (void)testCreateFulfilledShortcut {
   NSNumber *value = @1;
   APPromise *promise = [APPromise promiseFulfilledWithValue:value];
   [self assertIsPromise:promise fulfilledWithValue:value];
}

- (void)testCreateRejectedShortcut {
   NSNumber *reason = @1;
   APPromise *promise = [APPromise promiseRejectedWithReason:reason];
   [self assertIsPromise:promise rejectedWithReason:reason];
}

@end
