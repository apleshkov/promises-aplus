//
//  APPromise.m
//  promise-aplus
//
//  Created by Andrew Pleshkov on 5/31/13.
//  Copyright (c) 2013 Andrew Pleshkov. All rights reserved.
//

#import "APPromise.h"
#import "APPromise+Mutator.h"

/* Handler */

@interface APPromiseHandler : NSObject

- (instancetype)initWithPromise:(APPromise *)promise
                  dispatchQueue:(dispatch_queue_t)queue
                        fulfull:(APPromiseFulfillBlock)fulfill
                         reject:(APPromiseRejectBlock)reject;

- (void)fulfillWithValue:(id)value;
- (void)rejectWithReason:(id)reason;

@end

/* Class */

static char *const _kDefaultCommonQueueLabel = "promises.aplus.commonQueue";

@implementation APPromise {
   dispatch_queue_t _commonQueue;
   NSMutableArray *_handlers;
   
   APPromiseState _state;
   id _value, _reason;
}

- (void)dealloc {
   APPromiseDispatchRelease(_commonQueue);
}

- (instancetype)init {
   if (self = [super init]) {
      _commonQueue = dispatch_queue_create(_kDefaultCommonQueueLabel, NULL);
   }
   return self;
}

- (APPromiseState)state {
   __block APPromiseState state;
   dispatch_sync(_commonQueue, ^{
      state = _state;
   });
   return state;
}

- (id)value {
   __block id value;
   dispatch_sync(_commonQueue, ^{
      value = _value;
   });
   return value;
}

- (id)reason {
   __block id reason;
   dispatch_sync(_commonQueue, ^{
      reason = _reason;
   });
   return reason;
}

- (id<APPromise>)thenUseDispatchQueue:(dispatch_queue_t)queue
                          ifFulfilled:(APPromiseFulfillBlock)fulfilled
                             rejected:(APPromiseRejectBlock)rejected {
   APPromise *promise = [APPromise promise];
   
   dispatch_async(_commonQueue, ^{
      APPromiseHandler *handler = [[APPromiseHandler alloc] initWithPromise:promise
                                                              dispatchQueue:(queue == NULL ? dispatch_get_main_queue() : queue)
                                                                    fulfull:fulfilled
                                                                     reject:rejected];
      
      if (_state == APPromiseStateFulfilled) {
         [handler fulfillWithValue:_value];
         return;
      }
      
      if (_state == APPromiseStateRejected) {
         [handler rejectWithReason:_reason];
         return;
      }
      
      if (_state == APPromiseStatePending) {
         if ( ! _handlers) {
            _handlers = [NSMutableArray arrayWithObject:handler];
         } else {
            [_handlers addObject:handler];
         }
      }
   });
   
   return promise;
}

- (NSString *)description {
   NSString *state = ({
      NSString *desc = @"unknown";
      APPromiseState state = _state;
      if (state == APPromiseStatePending) {
         desc = @"pending";
      } else if (state == APPromiseStateFulfilled) {
         desc = [@"fulfilled with " stringByAppendingString:[_value description]];
      } else if (state == APPromiseStateRejected) {
         desc = [@"rejected with " stringByAppendingString:[_reason description]];
      }
      desc;
   });
   if (_name) {
      return [NSString stringWithFormat:@"<APPromise %p> name: \"%@\"; %@", self, _name, state];
   }
   return [NSString stringWithFormat:@"<APPromise %p> %@", self, state];
}

@end

@implementation APPromise (APPromiseStateShortcuts)

- (BOOL)isPending {
   return self.state == APPromiseStatePending;
}

- (BOOL)isFulfilled {
   return self.state == APPromiseStateFulfilled;
}

- (BOOL)isRejected {
   return self.state == APPromiseStateRejected;
}

@end

@implementation APPromise (APPromiseMutator)

- (void)fulfillWithValue:(id)value {
   dispatch_async(_commonQueue, ^{
      if (_state == APPromiseStatePending) {
         _state = APPromiseStateFulfilled;
         _value = value;
         
         for (APPromiseHandler *handler in _handlers) {
            [handler fulfillWithValue:value];
         }
         
         _handlers = nil;
      }
   });
}


- (void)rejectWithReason:(id)reason {
   dispatch_async(_commonQueue, ^{
      if (_state == APPromiseStatePending) {
         _state = APPromiseStateRejected;
         _reason = reason;
         
         for (APPromiseHandler *handler in _handlers) {
            [handler rejectWithReason:reason];
         }
         
         _handlers = nil;
      }
   });
}

@end

@implementation APPromise (APPromiseCreation)

+ (instancetype)promise {
   return [APPromise promiseWithName:nil];
}

+ (instancetype)promiseWithName:(NSString *)name {
   APPromise *promise = [APPromise new];
   promise.name = name;
   return promise;
}

@end

@implementation APPromise (APPromiseCreationShortcuts)

+ (instancetype)promiseFulfilledWithValue:(id)value {
   APPromise *promise = [APPromise promise];
   [promise fulfillWithValue:value];
   return promise;
}

+ (instancetype)promiseRejectedWithReason:(id)reason {
   APPromise *promise = [APPromise promise];
   [promise rejectWithReason:reason];
   return promise;
}

@end

/* Handler implementation */

@implementation APPromiseHandler {
   APPromise *_promise;
   dispatch_queue_t _queue;
   APPromiseFulfillBlock _fulfill;
   APPromiseRejectBlock _reject;
}

- (void)dealloc {
   APPromiseDispatchRelease(_queue);
}

- (instancetype)initWithPromise:(APPromise *)promise
                  dispatchQueue:(dispatch_queue_t)queue
                        fulfull:(APPromiseFulfillBlock)fulfill
                         reject:(APPromiseRejectBlock)reject {
   if (self = [self init]) {
      _promise = promise;
      
      APPromiseDispatchRetain(queue);
      _queue = queue;
      
      if (fulfill) {
         _fulfill = [fulfill copy];
      } else {
         _fulfill = ^id(id value) { return value; };
      }
      
      if (reject) {
         _reject = [reject copy];
      } else {
         _reject = ^id(id reason) { return reason; };
      }
   }
   return self;
}

- (BOOL)processResultAsPromiseIfPossible:(id)result {
   if ([result conformsToProtocol:@protocol(APPromise)]) {
      id<APPromise> returnedPromise = result;
      [returnedPromise thenUseDispatchQueue:_queue
                                ifFulfilled:^id(id value) {
                                   [_promise fulfillWithValue:value];
                                   return value;
                                } rejected:^id(id reason) {
                                   [_promise rejectWithReason:reason];
                                   return reason;
                                }];
      return YES;
   }
   return NO;
}

- (void)fulfillWithValue:(id)value {
   dispatch_async(_queue, ^{
      @try {
         id newValue = _fulfill(value);
         if ( ! [self processResultAsPromiseIfPossible:newValue]) {
            [_promise fulfillWithValue:newValue];
         }
      }
      @catch (NSException *exception) {
         [_promise rejectWithReason:_reject(exception)];
      }
   });
}

- (void)rejectWithReason:(id)reason {
   dispatch_async(_queue, ^{
      @try {
         id newReason = _reject(reason);
         if ( ! [self processResultAsPromiseIfPossible:newReason]) {
            [_promise rejectWithReason:newReason];
         }
      }
      @catch (NSException *exception) {
         [_promise rejectWithReason:_reject(exception)];
      }
   });
}

@end
